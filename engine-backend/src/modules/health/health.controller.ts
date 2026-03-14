import { Controller, Get } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { ReliabilityService } from '../reliability/reliability.service';

type FreshnessRow = QueryResultRow & {
  cell_freshness_seconds: number;
  max_stale_seconds: number;
};

type WorkerLagRow = QueryResultRow & {
  key: string;
  lag_seconds: number;
};

@Controller('health')
export class HealthController {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly reliabilityService: ReliabilityService,
  ) { }

  @Get('live')
  live() {
    return { status: 'ok' };
  }

  @Get('ready')
  async ready() {
    try {
      await this.databaseService.healthCheck();

      const stats = await this.databaseService.query<WorkerLagRow>(
        `SELECT
           key,
           COALESCE(last_run, updated_at) AS last_run,
           EXTRACT(EPOCH FROM (now() - COALESCE(last_run, updated_at)))::DOUBLE PRECISION AS lag_seconds
         FROM system_state
         WHERE key IN ('materialization_worker', 'lifecycle_worker')`,
      );

      const freshness = await this.databaseService.query<FreshnessRow>(
        `SELECT
           EXTRACT(EPOCH FROM (now() - COALESCE(MAX(updated_at), now())))::DOUBLE PRECISION AS cell_freshness_seconds,
           COALESCE(
             (SELECT value FROM model_parameters WHERE key = 'MATERIALIZATION_STALE_SECONDS'),
             300.0
           ) AS max_stale_seconds
         FROM risk_cells`,
      );

      const row = freshness.rows[0];
      const surfaceStale = row.cell_freshness_seconds > row.max_stale_seconds;

      const workerLagThresholds: Record<string, number> = {
        // 1-minute cron cadence + jitter tolerance.
        materialization_worker: 180,
        // 15-minute interval loop + startup/scheduling jitter tolerance.
        lifecycle_worker: 1200,
      };
      const defaultWorkerLagThreshold = 600;
      const resolveThreshold = (worker: string) =>
        workerLagThresholds[worker] ?? defaultWorkerLagThreshold;
      const laggingWorkers = stats.rows.filter((r) => r.lag_seconds > resolveThreshold(r.key));

      const replication = await this.databaseService.query<QueryResultRow>(
        `SELECT 
          EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::DOUBLE PRECISION AS replica_lag_seconds
         WHERE (SELECT pg_is_in_recovery())`
      );

      const replicaLag = replication.rows[0]?.replica_lag_seconds || 0;
      const lockStats = await this.databaseService.query<QueryResultRow>(
        `SELECT 
          COUNT(*)::INT as waiters,
          COALESCE(MAX(EXTRACT(EPOCH FROM (now() - state_change))), 0)::DOUBLE PRECISION as max_wait_seconds
         FROM pg_stat_activity 
         WHERE wait_event_type = 'Lock'`
      );

      const maxWait = lockStats.rows[0]?.max_wait_seconds || 0;
      const reliability = await this.reliabilityService.calculatePlatformReliability();
      const failureProb = await this.reliabilityService.estimateFailureProbability();

      const status = (surfaceStale || laggingWorkers.length > 0 || replicaLag > 60 || maxWait > 10 || reliability < 0.8) ? 'degraded' : 'ok';

      return {
        status,
        checks: {
          database: 'up',
          replicaLagSeconds: Number(replicaLag.toFixed(2)),
          lockWaiters: lockStats.rows[0]?.waiters || 0,
          maxLockWaitSeconds: Number(maxWait.toFixed(2)),
          riskSurface: {
            stale: surfaceStale,
            freshnessSeconds: Number(row.cell_freshness_seconds.toFixed(2)),
          },
          workers: stats.rows.map(r => ({
            name: r.key,
            lagSeconds: Number(r.lag_seconds.toFixed(2)),
            status: r.lag_seconds > resolveThreshold(r.key) ? 'stale' : 'healthy',
            heartbeat: r.lag_seconds < resolveThreshold(r.key),
          })),
          platformReliability: {
            score: reliability,
            failureProbability: failureProb,
            status: reliability > 0.9 ? 'stable' : reliability > 0.7 ? 'degraded' : 'critical',
          },
        },
      };
    } catch (error) {
      return {
        status: 'down',
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  // Legacy endpoint for backward compatibility (optional, but good for now)
  @Get()
  async health() {
    return this.ready();
  }
}
