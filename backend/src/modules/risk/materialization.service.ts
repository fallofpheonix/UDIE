import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class MaterializationService {
    private readonly logger = new Logger(MaterializationService.name);

    constructor(private readonly db: DatabaseService) { }

    @Cron(CronExpression.EVERY_MINUTE)
    async handleRiskSurfaceRefresh() {
        const start = performance.now();
        const workerName = 'materialization_worker';
        this.logger.log(`[MATERIALIZE] job_start=true worker=${workerName}`);

        try {
            // Acquire soft lock with 5-minute timeout
            const lockResult = await this.db.query<{ acquire_worker_lock: boolean }>(
                'SELECT acquire_worker_lock($1, $2)',
                [workerName, 300]
            );

            if (!lockResult.rows[0]?.acquire_worker_lock) {
                this.logger.log('[MATERIALIZE] skipped=true reason=lock-held-or-fresh');
                return;
            }

            await this.db.query('SELECT refresh_risk_surface()');

            const duration = (performance.now() - start).toFixed(2);
            await this.db.query(
                `SELECT set_system_state($1, $2::jsonb)`,
                [
                    workerName,
                    JSON.stringify({
                        status: 'OK',
                        duration_ms: Number(duration),
                        last_success_at: new Date().toISOString(),
                    }),
                ],
            );
            this.logger.log(`[MATERIALIZE] status=SUCCESS duration_ms=${duration}`);
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : 'unknown';
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
