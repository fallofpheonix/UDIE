import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';

export interface QueryPlanCheckResult {
  name: string;
  ok: boolean;
  hasSeqScan: boolean;
  hasNestedLoop: boolean;
  details: string;
}

@Injectable()
export class QueryPlanMonitor {
  private readonly smallTableThreshold = 1000;

  constructor(private readonly db: DatabaseService) {}

  async runRiskPlanAudit(): Promise<QueryPlanCheckResult> {
    const sample = await this.db.queryRead<QueryResultRow>(
      `SELECT h3_index
       FROM risk_cells
       ORDER BY updated_at DESC NULLS LAST, h3_index ASC
       LIMIT 1`,
    );

    if (sample.rows.length === 0) {
      return {
        name: 'risk_cells_hotpath',
        ok: true,
        hasSeqScan: false,
        hasNestedLoop: false,
        details: 'No risk_cells rows available for keyed hot-path audit.',
      };
    }

    const h3Index = Number((sample.rows[0] as Record<string, unknown>).h3_index);
    const plan = await this.explain(`
      SELECT weight
      FROM risk_cells
      WHERE h3_index = ${h3Index}
    `);

    const hasSeqScan = /Seq Scan/i.test(plan);
    const hasNestedLoop = /Nested Loop/i.test(plan);
    const rowCount = await this.tableRowCount('risk_cells');
    const executionMs = this.extractExecutionMs(plan);

    return {
      name: 'risk_cells_hotpath',
      ok: (!hasSeqScan || rowCount <= this.smallTableThreshold) && !hasNestedLoop && executionMs <= 5,
      hasSeqScan,
      hasNestedLoop,
      details: plan,
    };
  }

  async runRawEventGuardAudit(): Promise<QueryPlanCheckResult> {
    const plan = await this.explain(`
      SELECT id FROM events_log
      ORDER BY ingested_at DESC
      LIMIT 50
    `);

    const hasSeqScan = /Seq Scan/i.test(plan);
    const hasNestedLoop = /Nested Loop/i.test(plan);
    const rowCount = await this.tableRowCount('events_log');
    const executionMs = this.extractExecutionMs(plan);

    return {
      name: 'events_log_guard',
      ok: (!hasSeqScan || rowCount <= this.smallTableThreshold) && !hasNestedLoop && executionMs <= 15,
      hasSeqScan,
      hasNestedLoop,
      details: plan,
    };
  }

  private async explain(sql: string): Promise<string> {
    const result = await this.db.query<QueryResultRow>(`EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) ${sql}`);
    return result.rows
      .map((row) => String((row as unknown as Record<string, unknown>)['QUERY PLAN'] ?? Object.values(row)[0] ?? ''))
      .join('\n');
  }

  private async tableRowCount(tableName: 'risk_cells' | 'events_log'): Promise<number> {
    const result = await this.db.queryRead<QueryResultRow>(`SELECT COUNT(*)::int AS row_count FROM ${tableName}`);
    return Number((result.rows[0] as Record<string, unknown> | undefined)?.row_count ?? 0);
  }

  private extractExecutionMs(plan: string): number {
    const match = plan.match(/Execution Time:\s+([0-9.]+)\s+ms/i);
    return match ? Number(match[1]) : Number.POSITIVE_INFINITY;
  }
}
