import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class AnomalyDetectionService {
    private readonly logger = new Logger(AnomalyDetectionService.name);

    constructor(private readonly db: DatabaseService) { }

    /**
     * Detects risk spikes by comparing current cell weights to their 30-minute historical mean.
     * Spike Threshold: Current weight > (Mean + 2 * StdDev) OR Current weight > 2.0 * Mean.
     */
    async detectSpikes(): Promise<number> {
        const start = performance.now();

        // SQL Logic:
        // 1. Get average weight for each cell from risk_snapshots in the last 30m.
        // 2. Compare with current weight in risk_cells.
        // 3. Return count of cells exceeding the threshold.
        const result = await this.db.query(`
      WITH baseline AS (
        SELECT 
          h3_index,
          AVG(risk_weight) as avg_weight,
          STDDEV(risk_weight) as stddev_weight
        FROM risk_snapshots
        WHERE snapshot_time >= now() - interval '30 minutes'
        GROUP BY h3_index
      ),
      anomalies AS (
        SELECT 
          rc.h3_index,
          rc.weight as current_weight,
          b.avg_weight,
          b.stddev_weight
        FROM risk_cells rc
        JOIN baseline b ON rc.h3_index = b.h3_index
        WHERE rc.weight > 0.1 -- Noise floor
          AND (
            rc.weight > (b.avg_weight + 2 * COALESCE(b.stddev_weight, 0))
            OR rc.weight > (2.0 * b.avg_weight)
          )
      )
      SELECT h3_index, current_weight, avg_weight
      FROM anomalies
    `);

        const count = result.rowCount ?? 0;
        if (count > 0) {
            this.logger.warn(`[ANOMALY] Detected ${count} spatial risk spikes.`);
            // In a real system, we might emit events or insert into an anomalies table here.
            // For now, we log the top anomaly.
            if (result.rows.length > 0) {
                const top = result.rows[0];
                this.logger.debug(`[ANOMALY] Peak: cell=${top.h3_index} current=${top.current_weight.toFixed(3)} avg=${top.avg_weight.toFixed(3)}`);
            }
        }

        this.logger.log(`[ANOMALY] detection cycle complete. duration_ms=${(performance.now() - start).toFixed(2)}`);
        return count;
    }
}
