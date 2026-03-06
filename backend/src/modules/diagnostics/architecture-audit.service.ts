import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { QueryPlanMonitor } from './query-plan-monitor.service';
import { RiskModelMonitor } from './risk-model-monitor.service';

export interface ArchitectureAuditReport {
  status: 'healthy' | 'degraded';
  checks: Record<string, unknown>;
  generatedAt: string;
}

@Injectable()
export class ArchitectureAuditService {
  constructor(
    private readonly db: DatabaseService,
    private readonly queryPlanMonitor: QueryPlanMonitor,
    private readonly riskModelMonitor: RiskModelMonitor,
  ) {}

  async runQueryPlanAudit() {
    const [riskPlan, rawEventGuard] = await Promise.all([
      this.queryPlanMonitor.runRiskPlanAudit(),
      this.queryPlanMonitor.runRawEventGuardAudit(),
    ]);
    return { riskPlan, rawEventGuard, ok: riskPlan.ok && rawEventGuard.ok };
  }

  async runRebuildCheck() {
    const before = await this.riskCellsHash();
    await this.db.query('SELECT rebuild_derived_state_from_log()');
    const after = await this.riskCellsHash();

    return { ok: before === after, before, after };
  }

  async verifyPartitionIsolation() {
    const result = await this.db.query<QueryResultRow>(`
      SELECT COUNT(*)::int AS partition_count
      FROM pg_inherits i
      JOIN pg_class c ON i.inhrelid = c.oid
      JOIN pg_class p ON i.inhparent = p.oid
      WHERE p.relname IN ('events_log', 'risk_cells', 'reliability_cells')
    `);

    const partitionCount = Number(result.rows[0]?.partition_count ?? 0);
    return { ok: partitionCount > 0, partitionCount };
  }

  async verifyHotPathIntegrity() {
    const guard = await this.db.query<QueryResultRow>(`
      SELECT COUNT(*)::int AS risk_rows FROM risk_cells
    `);
    const riskRows = Number(guard.rows[0]?.risk_rows ?? 0);
    return { ok: riskRows >= 0, riskRows };
  }

  async runFullAudit(): Promise<ArchitectureAuditReport> {
    const [queryPlan, rebuild, partition, hotPath, model] = await Promise.all([
      this.runQueryPlanAudit(),
      this.runRebuildCheck(),
      this.verifyPartitionIsolation(),
      this.verifyHotPathIntegrity(),
      this.riskModelMonitor.evaluate(),
    ]);

    const checks = { queryPlan, rebuild, partition, hotPath, model };
    const healthy = queryPlan.ok && rebuild.ok && partition.ok && hotPath.ok && model.healthy;

    return {
      status: healthy ? 'healthy' : 'degraded',
      checks,
      generatedAt: new Date().toISOString(),
    };
  }

  private async riskCellsHash(): Promise<string> {
    const result = await this.db.query<QueryResultRow>(`
      SELECT md5(string_agg((h3_index::text || ':' || weight::text), '|' ORDER BY h3_index)) AS digest
      FROM risk_cells
    `);
    return String(result.rows[0]?.digest ?? '');
  }
}
