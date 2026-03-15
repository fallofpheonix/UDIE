import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { DatabaseService } from '../../database/database.service';
import { SpatialRiskFieldService } from './spatial-risk-field.service';
import { RiskStreamService } from './risk-stream.service';

@Injectable()
export class MaterializationService implements OnModuleInit {
    private readonly logger = new Logger(MaterializationService.name);
    private readonly workerLockTimeoutSeconds = 45;

    constructor(
      private readonly db: DatabaseService,
      private readonly spatialRiskField: SpatialRiskFieldService,
      private readonly riskStreamService: RiskStreamService,
    ) { }

    onModuleInit() {
      void this.handleRiskSurfaceRefresh();
    }

    @Cron(CronExpression.EVERY_MINUTE)
    async handleRiskSurfaceRefresh() {
        const start = performance.now();
        const workerName = 'materialization_worker';
        const lockId = 777123; // UDIE_MATERIALIZATION_LOCK

        this.logger.log(`[MATERIALIZE] job_start=true worker=${workerName}`);

        try {
            // 1. Session-level advisory lock (skip if already held)
            const advisoryLock = await this.db.query<{ pg_try_advisory_lock: boolean }>(
                'SELECT pg_try_advisory_lock($1)',
                [lockId]
            );

            if (!advisoryLock.rows[0]?.pg_try_advisory_lock) {
                this.logger.log('[MATERIALIZE] skipped=true reason=advisory-lock-held');
                return;
            }

            try {
                // 2. Acquire soft lock with 5-minute timeout for telemetry
                const lockResult = await this.db.query<{ acquire_worker_lock: boolean }>(
                    'SELECT acquire_worker_lock($1, $2)',
                    [workerName, this.workerLockTimeoutSeconds]
                );

                if (!lockResult.rows[0]?.acquire_worker_lock) {
                    this.logger.log('[MATERIALIZE] skipped=true reason=soft-lock-held');
                    return;
                }

                const stats = await this.spatialRiskField.refreshRiskField();
                await this.riskStreamService.broadcastSurfaceRefresh();

                const duration = (performance.now() - start).toFixed(2);
                await this.db.query(
                    `SELECT set_system_state($1, $2::jsonb)`,
                    [
                        workerName,
                        JSON.stringify({
                            status: 'OK',
                            duration_ms: Number(duration),
                            event_count: stats.eventCount,
                            cell_count: stats.cellCount,
                            last_success_at: new Date().toISOString(),
                        }),
                    ],
                );
                this.logger.log(`[MATERIALIZE] status=SUCCESS duration_ms=${duration}`);
            } finally {
                // 4. Always release advisory lock
                await this.db.query('SELECT pg_advisory_unlock($1)', [lockId]);
            }
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : 'unknown';
            try {
                await this.db.query(
                    `SELECT set_system_state($1, $2::jsonb)`,
                    [
                        workerName,
                        JSON.stringify({
                            status: 'FAILED',
                            last_failure_at: new Date().toISOString(),
                            error: message,
                        }),
                    ],
                );
            } catch (innerError) {
                this.logger.error(`[MATERIALIZE] Critical telemetry failure: ${innerError}`);
            }
            this.logger.error(`[MATERIALIZE] status=FAILED error=${message}`);
        }
    }

    @Cron(CronExpression.EVERY_WEEK)
    async handleLogPruning() {
        this.logger.log('[LIFECYCLE] pruning_start=true');
        try {
            const result = await this.db.query<{ purge_archived_events: number }>('SELECT purge_archived_events(90)');
            const count = result.rows[0]?.purge_archived_events ?? 0;
            this.logger.log(`[LIFECYCLE] pruning_complete=true deleted_count=${count}`);
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : 'unknown';
            this.logger.error(`[LIFECYCLE] pruning_failed=true error=${message}`);
        }
    }
}
