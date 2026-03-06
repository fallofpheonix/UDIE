import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import { Cron } from '@nestjs/schedule';

export interface ReliabilityInsight {
    h3Index: string;
    reliability: number;
    disruptionCount: number;
    avgSeverity: number;
}

@Injectable()
export class ReliabilityService {
    private readonly logger = new Logger(ReliabilityService.name);

    constructor(
        private readonly db: DatabaseService,
        private readonly spatial: SpatialService,
    ) { }

    /**
     * Daily job to aggregate long-term reliability scores.
     * Law: Heavy aggregations run asynchronously outside of the request path.
     */
    @Cron('0 0 2 * * *') // Run at 2 AM daily
    async runAggregation() {
        this.logger.log('[IRI] Starting 30-day reliability aggregation...');
        try {
            // 1. Get scaling factor K
            const kParam = await this.db.query('SELECT value FROM model_parameters WHERE key = $1', ['IRI_SCALING_K']);
            const k = parseFloat(kParam.rows[0]?.value || '100.0');

            // 2. Identify active cells in the last 30 days
            const activeCells = await this.db.query(`
        SELECT DISTINCT (payload->>'h3_index')::bigint as h3_index
        FROM regional_events_log
        WHERE created_at >= now() - interval '30 days'
          AND log_type = 'PROCESSED'
      `);

            this.logger.log(`[IRI] Aggregating ${activeCells.rows.length} active cells.`);

            for (const row of activeCells.rows) {
                await this.db.query('SELECT aggregate_cell_reliability($1, $2)', [row.h3_index, k]);
            }

            this.logger.log('[IRI] Aggregation complete.');
        } catch (error: any) {
            this.logger.error(`[IRI] Aggregation failed: ${error.message}`);
        }
    }

    /**
     * Spatially bounded query for reliability scores.
     */
    async getRegionalReliability(minLat: number, minLng: number, maxLat: number, maxLng: number): Promise<ReliabilityInsight[]> {
        // Law: Spatially bounded via H3 partitions
        const centerLat = (minLat + maxLat) / 2;
        const centerLng = (minLng + maxLng) / 2;
        const regionId = this.spatial.getRegionId(centerLat, centerLng);

        const result = await this.db.query(`
      SELECT 
        h3_index::text as h3_index,
        reliability_score as reliability,
        disruption_count as count,
        avg_severity as severity
      FROM reliability_cells
      WHERE h3_cell_to_parent(h3_index, 6)::text = $1
    `, [regionId]);

        return result.rows.map(row => ({
            h3Index: row.h3_index,
            reliability: row.reliability,
            disruptionCount: row.count,
            avgSeverity: row.severity,
        }));
    }
}
