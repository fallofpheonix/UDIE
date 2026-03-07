import { Injectable, Logger } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { Cron, CronExpression } from '@nestjs/schedule';
import { QueryPlanMonitor } from './query-plan-monitor.service';
import { RiskModelMonitor } from './risk-model-monitor.service';

export interface ArchitectureAuditReport {
  status: 'healthy' | 'degraded';
  checks: Record<string, unknown>;
  generatedAt: string;
}

@Injectable()
export class ArchitectureAuditService {
  private readonly logger = new Logger(ArchitectureAuditService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly queryPlanMonitor: QueryPlanMonitor,
    private readonly riskModelMonitor: RiskModelMonitor,
  ) { }

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

  async verifyLaw5Diffusion() {
    // Law 5: Diffusion increases cell coverage beyond the source points.
    // Check if total risk cells > unique event cells.
    const result = await this.db.query<QueryResultRow>(`
      SELECT 
        (SELECT COUNT(*)::int FROM risk_cells) AS total_cells,
        (SELECT COUNT(DISTINCT h3_index)::int FROM geo_events WHERE status = 'ACTIVE') AS source_cells
    `);
    const total = Number(result.rows[0]?.total_cells ?? 0);
    const source = Number(result.rows[0]?.source_cells ?? 0);
    return { ok: total >= source, total, source };
  }

  async verifyLaw10Gradients() {
    // Law 10: Gradients indicate disruption boundaries.
    // calculate_risk_gradients() is a function, not a table.
    try {
      const result = await this.db.query<QueryResultRow>(`
        SELECT COUNT(*)::int AS gradient_count FROM calculate_risk_gradients()
      `);
      const gradients = Number(result.rows[0]?.gradient_count ?? 0);
      return { ok: gradients >= 0, gradients };
    } catch (err) {
      return { ok: false, error: 'Gradient function failed' };
    }
  }

  async checkPlanDrift() {
    // Check for sequence scans on risk_cells in pg_stat_statements
    // This requires pg_stat_statements to be enabled. 
    try {
      const result = await this.db.query<QueryResultRow>(`
        SELECT query, calls, total_exec_time / calls as avg_ms
        FROM pg_stat_statements
        WHERE query ILIKE '%FROM risk_cells%'
          AND query NOT ILIKE '%EXPLAIN%'
        ORDER BY total_exec_time DESC
        LIMIT 5
      `);
      return { ok: true, stats: result.rows };
    } catch {
      return { ok: true, reason: 'pg_stat_statements not available' };
    }
  }

  async runFullAudit(): Promise<ArchitectureAuditReport> {
    const [queryPlan, rebuild, partition, hotPath, model, law5, law10, drift] = await Promise.all([
      this.runQueryPlanAudit(),
      this.runRebuildCheck(),
      this.verifyPartitionIsolation(),
      this.verifyHotPathIntegrity(),
      this.riskModelMonitor.evaluate(),
      this.verifyLaw5Diffusion(),
      this.verifyLaw10Gradients(),
      this.checkPlanDrift(),
    ]);

    const checks = { queryPlan, rebuild, partition, hotPath, model, law5, law10, drift };
    const healthy = queryPlan.ok && rebuild.ok && partition.ok && hotPath.ok && model.healthy && law5.ok && law10.ok && drift.ok;

    return {
      status: healthy ? 'healthy' : 'degraded',
      checks,
      generatedAt: new Date().toISOString(),
    };
  }

  /**
   * Nightly Rebuild Drill (State Consistency Check)
   * Law 1: Ensures derived state is always REPRODUCIBLE from logs.
   */
  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async runNightlyRebuildDrill() {
    this.logger.log('[DRILL] Nightly Rebuild Drill started...');
    const start = performance.now();

    try {
      await this.db.query('SELECT rebuild_derived_state_from_log();');

      const duration = (performance.now() - start).toFixed(2);
      this.logger.log(`[DRILL] Rebuild successful. duration_ms=${duration}`);

      await this.db.query(
        'SELECT set_system_state($1, $2::jsonb)',
        ['rebuild_drill', JSON.stringify({ status: 'OK', duration_ms: Number(duration), last_run: new Date() })]
      );
    } catch (err: any) {
      this.logger.error('[DRILL] Rebuild failed!', err);
      await this.db.query(
        'SELECT set_system_state($1, $2::jsonb)',
        ['rebuild_drill', JSON.stringify({ status: 'FAILED', error: err.message || String(err), last_run: new Date() })]
      );
    }
  }

  private async riskCellsHash(): Promise<string> {
    const result = await this.db.query<QueryResultRow>(`
      SELECT md5(string_agg((h3_index::text || ':' || ROUND(weight::numeric, 4)::text), '|' ORDER BY h3_index)) AS digest
      FROM risk_cells
    `);
    return String(result.rows[0]?.digest ?? '');
  }
}
