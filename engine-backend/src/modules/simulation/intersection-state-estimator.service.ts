import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { EstimateIntersectionStateDto } from './dto/estimate-intersection-state.dto';

type EstimateRow = QueryResultRow & {
  intersection_id: string;
  city_id: string;
  region_id: string | number | bigint;
  queue_length: number;
  vehicle_count: number;
  arrival_rate: number;
  average_speed: number;
  congestion_index: number;
};

@Injectable()
export class IntersectionStateEstimatorService {
  constructor(private readonly db: DatabaseService) {}

  async estimate(dto: EstimateIntersectionStateDto) {
    const result = await this.db.query<EstimateRow>(
      `
        WITH sensor_window AS (
          SELECT
            jsonb_array_elements_text(cg.intersection_ids) AS intersection_id,
            cg.city_id,
            cg.region_id,
            AVG(ts.vehicle_count) AS vehicle_count,
            AVG(ts.average_speed) AS average_speed,
            AVG(ts.traffic_density) AS traffic_density,
            AVG(ts.disruption_weight) AS disruption_weight
          FROM city_grid_cells cg
          JOIN digital_twin_traffic_samples ts ON ts.cell_id = cg.cell_id
          WHERE cg.intersection_ids ? $1
            AND ($2::text IS NULL OR cg.city_id = $2)
            AND ts.observed_at >= now() - make_interval(mins => $3)
          GROUP BY jsonb_array_elements_text(cg.intersection_ids), cg.city_id, cg.region_id
        )
        INSERT INTO intersection_state_estimates (
          intersection_id,
          city_id,
          region_id,
          queue_length,
          vehicle_count,
          arrival_rate,
          average_speed,
          congestion_index
        )
        SELECT
          intersection_id,
          city_id,
          region_id::bigint,
          GREATEST(0, vehicle_count * GREATEST(0.15, traffic_density * 0.55 + disruption_weight * 0.30)),
          vehicle_count,
          GREATEST(0, vehicle_count / GREATEST($3, 1)),
          average_speed,
          LEAST(1.5, GREATEST(0, traffic_density * 0.7 + disruption_weight * 0.25 + (1 - LEAST(average_speed, 80) / 80) * 0.35))
        FROM sensor_window
        ON CONFLICT (intersection_id) DO UPDATE
        SET city_id = EXCLUDED.city_id,
            region_id = EXCLUDED.region_id,
            queue_length = EXCLUDED.queue_length,
            vehicle_count = EXCLUDED.vehicle_count,
            arrival_rate = EXCLUDED.arrival_rate,
            average_speed = EXCLUDED.average_speed,
            congestion_index = EXCLUDED.congestion_index,
            estimated_at = now()
        RETURNING
          intersection_id,
          city_id,
          region_id::text AS region_id,
          queue_length,
          vehicle_count,
          arrival_rate,
          average_speed,
          congestion_index
      `,
      [dto.intersection_id, dto.city_id ?? null, dto.lookback_minutes],
    );

    const row = result.rows[0];
    if (!row) {
      throw new Error(`intersection estimate unavailable for ${dto.intersection_id}`);
    }

    return {
      intersectionId: row.intersection_id,
      cityId: row.city_id,
      regionId: String(row.region_id),
      queueLength: Number(row.queue_length ?? 0),
      vehicleCount: Number(row.vehicle_count ?? 0),
      arrivalRate: Number(row.arrival_rate ?? 0),
      averageSpeed: Number(row.average_speed ?? 0),
      congestionIndex: Number(row.congestion_index ?? 0),
    };
  }
}
