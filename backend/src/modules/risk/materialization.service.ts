import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';

type LockRow = QueryResultRow & { locked: boolean };

@Injectable()
export class MaterializationService {
    private readonly logger = new Logger(MaterializationService.name);
    private readonly advisoryLockKey = 41001;

    constructor(private readonly db: DatabaseService) { }

    @Cron(CronExpression.EVERY_MINUTE)
    async handleRiskSurfaceRefresh() {
        const start = performance.now();
        this.logger.log('[MATERIALIZE] job_start=true');

        try {
            const lockResult = await this.db.query<LockRow>('SELECT pg_try_advisory_lock($1) AS locked', [this.advisoryLockKey]);
            if (!lockResult.rows[0]?.locked) {
                this.logger.log('[MATERIALIZE] skipped=true reason=lock-held');
                return;
            }

            await this.db.query('SELECT refresh_risk_surface()');

            const duration = (performance.now() - start).toFixed(2);
            await this.db.query(
                `SELECT set_system_state($1, $2::jsonb)`,
                [
                    'materialization',
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
                    'materialization',
                    JSON.stringify({
                        status: 'FAILED',
                        last_failure_at: new Date().toISOString(),
                        error: message,
                    }),
                ],
            );
            this.logger.error(`[MATERIALIZE] status=FAILED error=${message}`);
        } finally {
            await this.db.query('SELECT pg_advisory_unlock($1)', [this.advisoryLockKey]);
        }
    }
}
