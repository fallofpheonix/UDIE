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
  constructor(private readonly db: DatabaseService) {}

  async runRiskPlanAudit(): Promise<QueryPlanCheckResult> {
    const plan = await this.explain(`
      SELECT (h3_index::h3index)::text, weight
      FROM risk_cells
      ORDER BY weight DESC
      LIMIT 50
    `);

    const hasSeqScan = /Seq Scan/i.test(plan);
    const hasNestedLoop = /Nested Loop/i.test(plan);

    return {
      name: 'risk_cells_hotpath',
      ok: !hasSeqScan,
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

    return {
      name: 'events_log_guard',
      ok: !hasSeqScan,
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
}
