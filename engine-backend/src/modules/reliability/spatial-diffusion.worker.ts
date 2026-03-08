import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class SpatialDiffusionWorker {
    private readonly logger = new Logger(SpatialDiffusionWorker.name);
    private readonly workerName = 'spatial_diffusion_worker';

    constructor(private readonly db: DatabaseService) { }

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
            // Use existing worker lock mechanism
            const lockResult = await this.db.query(
                'SELECT acquire_worker_lock($1, $2) AS locked',
                [this.workerName, 300] // 5 minute timeout
            );

            if (!lockResult.rows[0]?.locked) {
                this.logger.debug('[DIFFUSION] skipped: lock held');
                return;
            }

            const hasV2 = await this.hasRefreshRiskSurfaceV2();
            if (hasV2) {
                await this.db.query('SELECT refresh_risk_surface_v2();');
            } else {
                // Backward compatibility for databases missing migration 038/042.
                await this.db.query('SELECT refresh_risk_surface();');
            }

            const duration = (performance.now() - start).toFixed(2);
            this.logger.log(`[DIFFUSION] status=SUCCESS duration_ms=${duration}`);

            await this.db.query(
                'SELECT set_system_state($1, $2::jsonb)',
                ['spatial_diffusion', JSON.stringify({ status: 'OK', last_run: new Date(), duration_ms: Number(duration) })]
            );
        } catch (error: any) {
            this.logger.error(`[DIFFUSION] status=FAILED error=${error.message}`);
        }
    }

    private async hasRefreshRiskSurfaceV2(): Promise<boolean> {
        const result = await this.db.query<QueryResultRow>(
            `SELECT to_regprocedure('public.refresh_risk_surface_v2()') IS NOT NULL AS present`,
        );
        return Boolean(result.rows[0]?.present);
    }
}
