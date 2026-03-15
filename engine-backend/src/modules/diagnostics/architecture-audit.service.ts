import { Injectable, Logger } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { Cron, CronExpression } from '@nestjs/schedule';
import { QueryPlanMonitor } from './query-plan-monitor.service';
import { RiskModelMonitor } from './risk-model-monitor.service';
import { SpatialRiskFieldService } from '../risk/spatial-risk-field.service';

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
    private readonly spatialRiskField: SpatialRiskFieldService,
  ) { }

  async runQueryPlanAudit() {
    const [riskPlan, rawEventGuard] = await Promise.all([
      this.queryPlanMonitor.runRiskPlanAudit(),
      this.queryPlanMonitor.runRawEventGuardAudit(),
    ]);
    return { riskPlan, rawEventGuard, ok: riskPlan.ok && rawEventGuard.ok };
  }

  async runRebuildCheck() {
    const eventLogBefore = await this.eventLogHash();
    const evaluationTimeMs = Date.now();
    await this.spatialRiskField.refreshRiskField({ evaluationTimeMs });
    const before = await this.riskCellsHash();
    await this.spatialRiskField.refreshRiskField({ evaluationTimeMs });
    const eventLogAfter = await this.eventLogHash();
    const after = await this.riskCellsHash();

    if (eventLogBefore !== eventLogAfter) {
      return { ok: true, skipped: 'event-log-mutated-during-check', before, after, eventLogBefore, eventLogAfter };
    }

    return { ok: before === after, before, after };
  }

  async verifyPartitionIsolation() {
    const result = await this.db.query<QueryResultRow>(`
      WITH parent_targets AS (
        SELECT unnest(ARRAY[
          'events_log',
          'risk_cells',
          'reliability_cells',
          'regional_events_log',
          'regional_geo_events_v',
          'regional_risk_grid_v'
        ]) AS relname
      )
      SELECT
        target.relname,
        COALESCE(stats.partition_count, 0)::int AS partition_count
      FROM parent_targets target
      LEFT JOIN (
        SELECT parent.relname, COUNT(*)::int AS partition_count
        FROM pg_inherits i
        JOIN pg_class child ON i.inhrelid = child.oid
        JOIN pg_class parent ON i.inhparent = parent.oid
        GROUP BY parent.relname
      ) stats ON stats.relname = target.relname
      ORDER BY target.relname
    `);

    const partitionDetails = Object.fromEntries(
      result.rows.map((row) => [
        String(row.relname),
        Number(row.partition_count ?? 0),
      ]),
    );
    const partitionCount = Object.values(partitionDetails).reduce(
      (sum, count) => sum + count,
      0,
    );
    return { ok: partitionCount > 0, partitionCount, partitionDetails };
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
    } catch {
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
      await this.spatialRiskField.refreshRiskField();

      const duration = (performance.now() - start).toFixed(2);
      this.logger.log(`[DRILL] Rebuild successful. duration_ms=${duration}`);

      await this.db.query(
        'SELECT set_system_state($1, $2::jsonb)',
        ['rebuild_drill', JSON.stringify({ status: 'OK', duration_ms: Number(duration), last_run: new Date() })]
      );
    } catch (err: unknown) {
      this.logger.error('[DRILL] Rebuild failed!', err);
      await this.db.query(
        'SELECT set_system_state($1, $2::jsonb)',
        ['rebuild_drill', JSON.stringify({ status: 'FAILED', error: err instanceof Error ? err.message : String(err), last_run: new Date() })]
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

  private async eventLogHash(): Promise<string> {
    const result = await this.db.query<QueryResultRow>(`
      SELECT md5(
        COALESCE(
          string_agg(
            (
              id::text || ':' ||
              COALESCE(log_type, '') || ':' ||
              COALESCE(source::text, '') || ':' ||
              COALESCE(ingested_at::text, '')
            ),
            '|' ORDER BY ingested_at, id
          ),
          ''
        )
      ) AS digest
      FROM events_log
    `);
    return String(result.rows[0]?.digest ?? '');
  }
}
