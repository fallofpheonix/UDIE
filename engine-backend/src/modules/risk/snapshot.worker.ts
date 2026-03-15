import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class SnapshotWorker {
    private readonly logger = new Logger(SnapshotWorker.name);

    constructor(private readonly db: DatabaseService) { }

    /**
     * Captures the current state of risk_cells every 5 minutes.
     * Law: Snapshots must be spatially granular (H3 Res 9).
     */
    @Cron(CronExpression.EVERY_5_MINUTES)
    async captureSnapshot() {
        this.logger.log('[SNAPSHOT] Periodic capture starting...');
        const start = performance.now();

        try {
            // Direct insertion from current risk_cells state
            const result = await this.db.query(`
        INSERT INTO risk_snapshots (snapshot_time, h3_index, risk_weight)
        SELECT now(), h3_index, weight
        FROM risk_cells
        WHERE weight > 0.01 -- Sparse optimization: skip negligible risk
      `);

            const duration = (performance.now() - start).toFixed(2);
            this.logger.log(`[SNAPSHOT] Captured ${result.rowCount} cells in ${duration}ms`);
        } catch (error: unknown) {
            this.logger.error(`[SNAPSHOT] Capture failed: ${error instanceof Error ? error.message : String(error)}`);
        }
    }
}
