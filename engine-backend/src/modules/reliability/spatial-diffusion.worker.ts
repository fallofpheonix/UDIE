import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { DatabaseService } from '../../database/database.service';
import { SpatialRiskFieldService } from '../risk/spatial-risk-field.service';

@Injectable()
export class SpatialDiffusionWorker {
    private readonly logger = new Logger(SpatialDiffusionWorker.name);
    private readonly workerName = 'spatial_diffusion_worker';
    private readonly materializationLockId = 777123; // UDIE_MATERIALIZATION_LOCK

    constructor(
      private readonly db: DatabaseService,
      private readonly spatialRiskField: SpatialRiskFieldService,
    ) { }

    /**
     * Law 5: Physical Spatial Diffusion
     * Periodically triggers the physical diffusion kernel in the database.
     * This ensures risk "spreads" naturally and decays over space/time.
     */
    @Cron(CronExpression.EVERY_5_MINUTES)
    async runDiffusionCycle() {
        this.logger.log('[DIFFUSION] starting cycle...');
        const start = performance.now();

        try {
            const advisoryLock = await this.db.query<{ pg_try_advisory_lock: boolean }>(
                'SELECT pg_try_advisory_lock($1)',
                [this.materializationLockId],
            );

            if (!advisoryLock.rows[0]?.pg_try_advisory_lock) {
                this.logger.debug('[DIFFUSION] skipped: materialization lock held');
                return;
            }

            // Use existing worker lock mechanism
            try {
                const lockResult = await this.db.query(
                    'SELECT acquire_worker_lock($1, $2) AS locked',
                    [this.workerName, 300] // 5 minute timeout
                );

                if (!lockResult.rows[0]?.locked) {
                    this.logger.debug('[DIFFUSION] skipped: lock held');
                    return;
                }

                const stats = await this.spatialRiskField.refreshRiskField();

                const duration = (performance.now() - start).toFixed(2);
                this.logger.log(`[DIFFUSION] status=SUCCESS duration_ms=${duration} cells=${stats.cellCount}`);

                await this.db.query(
                    'SELECT set_system_state($1, $2::jsonb)',
                    ['spatial_diffusion', JSON.stringify({ status: 'OK', last_run: new Date(), duration_ms: Number(duration), cell_count: stats.cellCount })]
                );
            } finally {
                await this.db.query('SELECT pg_advisory_unlock($1)', [this.materializationLockId]);
            }
        } catch (error: unknown) {
            this.logger.error(`[DIFFUSION] status=FAILED error=${error instanceof Error ? error.message : String(error)}`);
        }
    }
}
