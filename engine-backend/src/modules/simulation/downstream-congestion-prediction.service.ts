import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { PredictDownstreamCongestionDto } from './dto/predict-downstream-congestion.dto';

type NodeRow = QueryResultRow & {
  target_intersection_id: string;
  queue_length: number;
  vehicle_count: number;
  arrival_rate: number;
  average_speed: number;
  congestion_index: number;
  capacity: number;
  length_meters: number;
  speed_limit: number;
};

@Injectable()
export class DownstreamCongestionPredictionService {
  constructor(private readonly db: DatabaseService) {}

  async predict(dto: PredictDownstreamCongestionDto) {
    const result = await this.db.queryRead<NodeRow>(
      `
        SELECT
          edge.target_intersection_id,
          COALESCE(est.queue_length, 0) AS queue_length,
          COALESCE(est.vehicle_count, 0) AS vehicle_count,
          COALESCE(est.arrival_rate, 0) AS arrival_rate,
          COALESCE(est.average_speed, 0) AS average_speed,
          COALESCE(est.congestion_index, 0) AS congestion_index,
          edge.capacity,
          edge.length_meters,
          edge.speed_limit
        FROM intersection_graph_edges edge
        LEFT JOIN intersection_state_estimates est
          ON est.intersection_id = edge.target_intersection_id
        WHERE edge.source_intersection_id = $1
          AND ($2::text IS NULL OR edge.city_id = $2)
        ORDER BY edge.target_intersection_id
      `,
      [dto.intersection_id, dto.city_id ?? null],
    );

    const predictions = result.rows.map((row) => {
      const predicted = this.predictNode(row, dto.horizon_steps);
      return {
        intersectionId: row.target_intersection_id,
        predictedCongestion: predicted.predictedCongestion,
        predictedQueueLength: predicted.predictedQueueLength,
        predictedAverageSpeed: predicted.predictedAverageSpeed,
      };
    });

    return {
      sourceIntersectionId: dto.intersection_id,
      horizonSteps: dto.horizon_steps,
      model: 'graph-diffusion-forecast',
      predictions,
    };
  }

  private predictNode(row: NodeRow, horizonSteps: number) {
    let congestion = Number(row.congestion_index ?? 0);
    let queue = Number(row.queue_length ?? 0);
    let speed = Number(row.average_speed ?? 0);
    const capacity = Math.max(Number(row.capacity ?? 1), 1);
    const flowBias = (Number(row.arrival_rate ?? 0) + Number(row.vehicle_count ?? 0) * 0.08) / capacity;
    const topologyFactor = Math.min(2, Number(row.length_meters ?? 300) / Math.max(Number(row.speed_limit ?? 40), 10) / 20);

    for (let i = 0; i < horizonSteps; i++) {
      congestion = Math.min(1.5, Math.max(0, congestion * 0.78 + flowBias * 0.55 + topologyFactor * 0.12));
      queue = Math.max(0, queue * 0.84 + Number(row.arrival_rate ?? 0) * 0.65 + congestion * 8);
      speed = Math.max(5, Math.min(Number(row.speed_limit ?? 40), speed * (1 - congestion * 0.18) + 1.5));
    }

    return {
      predictedCongestion: Number(congestion.toFixed(6)),
      predictedQueueLength: Number(queue.toFixed(3)),
      predictedAverageSpeed: Number(speed.toFixed(3)),
    };
  }
}
