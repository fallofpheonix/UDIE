import { Controller, Get, Query, Logger } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';

@Controller('api/risk-snapshots')
export class RiskSnapshotsController {
    private readonly logger = new Logger(RiskSnapshotsController.name);

    constructor(
        private readonly db: DatabaseService,
        private readonly spatial: SpatialService
    ) { }

    /**
     * Returns snapshots for a given time range and region.
     * Region is derived from H3 parent or BBox.
     */
    @Get()
    async getSnapshots(
        @Query('start_time') startTime: string,
        @Query('end_time') endTime: string,
        @Query('lat') lat?: number,
        @Query('lng') lng?: number,
        @Query('radius_km') radiusKm: number = 5
    ) {
        const start = performance.now();

        // 1. Spatial bounding logic
        let filterClause = '';
        const params: unknown[] = [startTime, endTime];

        if (lat && lng) {
            const centerCell = this.spatial.getH3Index(lat, lng);
            // Roughly map radius to H3 k-ring
            const rings = Math.max(1, Math.floor(radiusKm / 0.5));
            const neighbors = this.spatial.getInfluenceNeighbors(centerCell, rings);

            filterClause = `AND h3_index = ANY($3::bigint[])`;
            params.push(neighbors.map(n => BigInt(n)));
        }

        // 2. Query snapshots
        const result = await this.db.query(`
      SELECT 
        snapshot_time,
        h3_index::text as h3_index,
        risk_weight
      FROM risk_snapshots
      WHERE snapshot_time >= $1::timestamptz
        AND snapshot_time <= $2::timestamptz
        ${filterClause}
      ORDER BY snapshot_time ASC
    `, params);

        const duration = (performance.now() - start).toFixed(2);
        this.logger.debug(`[SNAPSHOT_API] found=${result.rows.length} latency=${duration}ms`);

        return {
            count: result.rows.length,
            snapshots: result.rows,
            latencyMs: parseFloat(duration)
        };
    }
}
