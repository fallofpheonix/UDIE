import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { TrainCoordinationDto } from './dto/train-coordination.dto';
import { TrafficSignalAIService } from './traffic-signal-ai.service';
import { signalActions } from './traffic-signal.types';

type CoordinationRow = QueryResultRow & {
  source_intersection_id: string;
  target_intersection_id: string;
  queue_length: number;
  arrival_rate: number;
  congestion_index: number;
};

@Injectable()
export class IntersectionCoordinationService {
  constructor(
    private readonly db: DatabaseService,
    private readonly trafficSignalAI: TrafficSignalAIService,
  ) {}

  async coordinate(cityId?: string) {
    const graph = await this.db.queryRead<CoordinationRow>(
      `
        SELECT
          edge.source_intersection_id,
          edge.target_intersection_id,
          COALESCE(est.queue_length, 0) AS queue_length,
          COALESCE(est.arrival_rate, 0) AS arrival_rate,
          COALESCE(est.congestion_index, 0) AS congestion_index
        FROM intersection_graph_edges edge
        LEFT JOIN intersection_state_estimates est
          ON est.intersection_id = edge.target_intersection_id
        WHERE ($1::text IS NULL OR edge.city_id = $1)
      `,
      [cityId ?? null],
    );

    const messages = new Map();
    for (const row of graph.rows) {
      const key = String(row.source_intersection_id);
      const current = messages.get(key) ?? { queue: 0, inflow: 0, congestion: 0, degree: 0 };
      current.queue += Number(row.queue_length ?? 0);
      current.inflow += Number(row.arrival_rate ?? 0);
      current.congestion += Number(row.congestion_index ?? 0);
      current.degree += 1;
      messages.set(key, current);
    }

    const coordinatedActions = [];
    for (const [intersectionId, message] of messages.entries()) {
      const agent = await this.trafficSignalAI.getIntersectionAgent(intersectionId, cityId);
      const neighborQueue = message.degree > 0 ? message.queue / message.degree : 0;
      const neighborInflow = message.degree > 0 ? message.inflow / message.degree : 0;
      const neighborCongestion = message.degree > 0 ? message.congestion / message.degree : 0;

      const action =
        neighborQueue > 18 || neighborCongestion > 0.8 || neighborInflow > 6
          ? 'extend_green'
          : agent.agent.phaseElapsedSeconds >= agent.agent.minPhaseSeconds && neighborCongestion < 0.45
            ? 'switch_phase'
            : 'hold_phase';

      coordinatedActions.push({
        intersectionId,
        action,
        exchangedState: {
          queueLength: Number(neighborQueue.toFixed(3)),
          vehicleInflow: Number(neighborInflow.toFixed(3)),
          congestionLevel: Number(neighborCongestion.toFixed(6)),
        },
      });
    }

    return {
      cityId: cityId ?? null,
      coordinatedActions,
    };
  }

  async train(dto: TrainCoordinationDto) {
    const episodeRewards = [];

    for (let episode = 0; episode < dto.episodes; episode++) {
      let totalReward = 0;
      for (let step = 0; step < dto.max_steps; step++) {
        const coordination = await this.coordinate(dto.city_id);
        totalReward += coordination.coordinatedActions.reduce((sum, entry) => {
          const positive = entry.exchangedState.queueLength * 0.15 + entry.exchangedState.vehicleInflow * 0.08;
          const negative = entry.exchangedState.congestionLevel * 2.0;
          return sum + positive - negative;
        }, 0);
      }
      episodeRewards.push(Number(totalReward.toFixed(6)));
    }

    return {
      algorithm: 'graph-message-coordination',
      episodes: dto.episodes,
      averageReward: Number(
        (
          episodeRewards.reduce((sum, value) => sum + value, 0) /
          Math.max(episodeRewards.length, 1)
        ).toFixed(6),
      ),
      actionSpace: signalActions,
      episodeRewards,
    };
  }
}
