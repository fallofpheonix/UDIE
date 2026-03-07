import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { Interval } from '@nestjs/schedule';
import { QueryResultRow } from 'pg';

type LockRow = QueryResultRow & { locked: boolean };

@Injectable()
export class LifecycleService implements OnModuleInit {
    private readonly logger = new Logger(LifecycleService.name);
    private readonly workerName = 'lifecycle_worker';

    constructor(private readonly db: DatabaseService) { }

    onModuleInit() {
        this.logger.log('LifecycleService initialized. Starting maintenance loop...');
    }

    /**
     * Phase B: Automated Maintenance Job
     * Runs every 15 minutes to:
     * 1. Expire events past their end_time.
     * 2. Apply confidence decay.
     * 3. Archive events below threshold.
     */
    @Interval(900000) // 15 minutes
    async handleMaintenance() {
        this.logger.log('[LIFECYCLE] job_start=true');
        const start = performance.now();

        try {
            const lockResult = await this.db.query(
                'SELECT acquire_worker_lock($1, $2) AS locked',
                [this.workerName, 900] // 15 minute timeout
            );
            if (!lockResult.rows[0]?.locked) {
                this.logger.log('[LIFECYCLE] skipped=true reason=lock-held');
                return;
            }

            await this.db.query(`SELECT set_config('udie.allow_derived_mutation', 'true', true)`);
            await this.db.query('SELECT run_lifecycle_maintenance();');
            await this.db.query(`SELECT set_config('udie.allow_derived_mutation', 'false', true)`);
            const duration = (performance.now() - start).toFixed(2);
            await this.db.query(
                `SELECT set_system_state($1, $2::jsonb)`,
                [
                    'lifecycle',
                    JSON.stringify({
                        status: 'OK',
                        duration_ms: Number(duration),
                        last_success_at: new Date().toISOString(),
                    }),
                ],
            );
            this.logger.log(`[LIFECYCLE] status=SUCCESS duration_ms=${duration}`);
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : 'unknown';
            await this.db.query(
                `SELECT set_system_state($1, $2::jsonb)`,
                [
                    'lifecycle',
                    JSON.stringify({
                        status: 'FAILED',
                        last_failure_at: new Date().toISOString(),
                        error: message,
                    }),
                ],
            );
            this.logger.error(`[LIFECYCLE] status=FAILED error=${message}`);
            try {
                await this.db.query(`SELECT set_config('udie.allow_derived_mutation', 'false', true)`);
            } catch {
                // best effort reset
            }
        } finally {
            // Heartbeat/lock handled by acquire_worker_lock in DB
        }
    }
}
