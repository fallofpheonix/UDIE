import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { ResetTrafficSignalEnvironmentDto } from './dto/reset-traffic-signal-environment.dto';
import { StepTrafficSignalEnvironmentDto } from './dto/step-traffic-signal-environment.dto';
import {
  IntersectionAgentState,
  SignalAction,
  SignalPhase,
  signalActions,
} from './traffic-signal.types';

type AggregateRow = QueryResultRow & {
  city_id: string;
  region_id: string | number | bigint;
  controlled_cells: Array<string | number | bigint> | null;
  controlled_cell_count: number;
  incoming_vehicle_count: number;
  avg_speed: number;
  nearby_congestion_index: number;
  saturation_flow: number;
};

type StateRow = QueryResultRow & {
  intersection_id: string;
  city_id: string;
  region_id: string | number | bigint;
  controlled_cells: Array<string | number | bigint> | null;
  controlled_cell_count: number;
  signal_phase: SignalPhase;
  phase_elapsed_seconds: number;
  phase_duration_seconds: number;
  min_phase_seconds: number;
  max_phase_seconds: number;
  yellow_seconds: number;
  queue_length: number;
  avg_wait_seconds: number;
  throughput_vehicles: number;
  incoming_vehicle_count: number;
  avg_speed: number;
  nearby_congestion_index: number;
  saturation_flow: number;
};

@Injectable()
export class TrafficSignalAIService {
  private readonly defaultPhaseSeconds = 30;
  private readonly defaultMinPhaseSeconds = 15;
  private readonly defaultMaxPhaseSeconds = 90;
  private readonly defaultYellowSeconds = 3;

  constructor(private readonly db: DatabaseService) {}

  async getIntersectionAgent(intersectionId: string, cityId?: string) {
    const state = await this.hydrateIntersectionState(intersectionId, cityId, false);
    return {
      agent: this.mapState(state),
      actionSpace: signalActions,
    };
  }

  async resetEnvironment(dto: ResetTrafficSignalEnvironmentDto) {
    const intersectionIds =
      dto.intersection_ids?.length ? dto.intersection_ids : await this.listIntersectionIds(dto.city_id, dto.limit);
    const episodeId = randomUUID();
    const agents = [];

    for (const intersectionId of intersectionIds) {
      const state = await this.hydrateIntersectionState(intersectionId, dto.city_id, true);
      agents.push(this.mapState(state));
    }

    return {
      episodeId,
      tickSeconds: 5,
      actionSpace: signalActions,
      intersections: agents,
    };
  }

  async stepEnvironment(dto: StepTrafficSignalEnvironmentDto) {
    const episodeId = dto.episode_id ?? randomUUID();
    const results = [];

    for (const entry of dto.actions) {
      const current = await this.hydrateIntersectionState(entry.intersection_id, undefined, false);
      const evaluation = this.evaluateTransition(current, entry.action, dto.tick_seconds);
      await this.persistStep(current.intersection_id, evaluation.nextState, episodeId, dto.step_index, entry.action, evaluation.reward);
      results.push({
        intersectionId: current.intersection_id,
        action: entry.action,
        validAction: evaluation.validAction,
        reward: evaluation.reward,
        state: this.mapState(current),
        nextState: evaluation.nextState,
      });
    }

    return {
      episodeId,
      stepIndex: dto.step_index,
      tickSeconds: dto.tick_seconds,
      transitions: results,
    };
  }

  createSyntheticState(intersectionId: string, cityId = 'sim-city', regionId = '0', seed = 1): IntersectionAgentState {
    const normalized = ((seed * 9301 + 49297) % 233280) / 233280;
    const queueLength = 8 + normalized * 32;
    const avgSpeed = 18 + (1 - normalized) * 28;
    const congestion = 0.35 + normalized * 0.75;
    const phaseDurationSeconds = 25 + Math.floor(normalized * 25);
    const phaseElapsedSeconds = Math.floor(normalized * phaseDurationSeconds);
    return {
      intersectionId,
      incomingVehicleCount: Number((18 + normalized * 54).toFixed(3)),
      avgSpeed: Number(avgSpeed.toFixed(3)),
      signalPhase: normalized > 0.5 ? 'NS_GREEN' : 'EW_GREEN',
      nearbyCongestionIndex: Number(congestion.toFixed(6)),
      queueLength: Number(queueLength.toFixed(3)),
      avgWaitSeconds: Number((12 + normalized * 35).toFixed(3)),
      throughputVehicles: Number((6 + (1 - normalized) * 10).toFixed(3)),
      phaseElapsedSeconds,
      phaseDurationSeconds,
      minPhaseSeconds: this.defaultMinPhaseSeconds,
      maxPhaseSeconds: this.defaultMaxPhaseSeconds,
      yellowSeconds: this.defaultYellowSeconds,
      saturationFlow: Number((28 + normalized * 20).toFixed(3)),
      cityId,
      regionId,
      controlledCellCount: 1 + Math.floor(normalized * 3),
    };
  }

  simulateTransition(state: IntersectionAgentState, action: SignalAction, tickSeconds: number) {
    const phase = this.applyAction(
      state.signalPhase,
      state.phaseDurationSeconds,
      state.phaseElapsedSeconds,
      state.minPhaseSeconds,
      state.maxPhaseSeconds,
      state.yellowSeconds,
      action,
      tickSeconds,
    );

    const arrivalRatePerMinute = Math.max(
      4,
      state.incomingVehicleCount * 0.18 +
        state.nearbyCongestionIndex * 14 +
        (1 - Math.min(state.avgSpeed, 80) / 80) * 18,
    );
    const arrivals = arrivalRatePerMinute * (tickSeconds / 60);

    const switchPenalty = phase.phaseSwitched
      ? Math.min(0.65, state.yellowSeconds / Math.max(tickSeconds, state.yellowSeconds))
      : 0;
    const serviceFactor =
      phase.nextPhase === 'NS_GREEN' || phase.nextPhase === 'EW_GREEN' ? 1 - switchPenalty : 0;
    const dischargeCapacity = Math.max(
      2,
      state.saturationFlow * serviceFactor * (1 - Math.min(0.7, state.nearbyCongestionIndex * 0.35)),
    );
    const discharge = Math.min(state.queueLength + arrivals, dischargeCapacity * (tickSeconds / 60));
    const nextQueue = Math.max(0, state.queueLength + arrivals - discharge);
    const spillback = Math.max(0, nextQueue - state.saturationFlow);
    const nextWait = Math.max(0, state.avgWaitSeconds * 0.88 + nextQueue * 0.7 - discharge * 0.12);
    const nextSpeed = Math.max(
      5,
      Math.min(
        80,
        state.avgSpeed +
          discharge * 0.14 -
          nextQueue * 0.05 -
          state.nearbyCongestionIndex * 1.9 -
          spillback * 0.03,
      ),
    );
    const nextIncoming = Math.max(0, arrivals * 12);
    const nextCongestion = Math.max(
      0,
      Math.min(
        1.5,
        state.nearbyCongestionIndex * 0.76 +
          (nextQueue / Math.max(state.saturationFlow, 1)) * 0.45 +
          (1 - nextSpeed / 80) * 0.35,
      ),
    );

    const nextState: IntersectionAgentState = {
      ...state,
      signalPhase: phase.nextPhase,
      phaseDurationSeconds: phase.nextDurationSeconds,
      phaseElapsedSeconds: phase.nextElapsedSeconds,
      incomingVehicleCount: Number(nextIncoming.toFixed(3)),
      avgSpeed: Number(nextSpeed.toFixed(3)),
      nearbyCongestionIndex: Number(nextCongestion.toFixed(6)),
      queueLength: Number(nextQueue.toFixed(3)),
      avgWaitSeconds: Number(nextWait.toFixed(3)),
      throughputVehicles: Number(discharge.toFixed(3)),
    };

    return {
      validAction: phase.validAction,
      nextState,
      reward: this.computeReward(state, nextState, phase.validAction),
    };
  }

  async listActions() {
    return {
      actions: signalActions.map((action) => ({
        action,
        constraints: this.describeActionConstraints(action),
      })),
      phases: ['NS_GREEN', 'EW_GREEN'],
    };
  }

  private async listIntersectionIds(cityId: string | undefined, limit: number) {
    const result = await this.db.queryRead<QueryResultRow>(
      `
        SELECT DISTINCT jsonb_array_elements_text(cg.intersection_ids) AS intersection_id
        FROM city_grid_cells cg
        WHERE cg.intersection_ids <> '[]'::jsonb
          AND ($1::text IS NULL OR cg.city_id = $1)
        LIMIT $2
      `,
      [cityId ?? null, limit],
    );
    return result.rows.map((row) => String(row.intersection_id));
  }

  private async hydrateIntersectionState(intersectionId: string, cityId?: string, resetControl = false) {
    const aggregate = await this.db.queryRead<AggregateRow>(
      `
        WITH controlled AS (
          SELECT
            cg.cell_id,
            cg.city_id,
            cg.region_id,
            COALESCE(ds.vehicle_count, 0) AS vehicle_count,
            COALESCE(ds.average_speed, 0) AS average_speed,
            COALESCE(ds.traffic_density, 0) AS traffic_density,
            COALESCE(ds.risk_score, 0) AS risk_score,
            COALESCE(cg.road_capacity, 250) AS road_capacity
          FROM city_grid_cells cg
          LEFT JOIN digital_twin_cell_states ds ON ds.cell_id = cg.cell_id
          WHERE cg.intersection_ids ? $1
            AND ($2::text IS NULL OR cg.city_id = $2)
        ),
        adjacency AS (
          SELECT
            COALESCE(AVG(ds.traffic_density), 0) AS avg_density,
            COALESCE(AVG(ds.risk_score), 0) AS avg_risk
          FROM city_grid_edges edge
          JOIN controlled c ON c.cell_id = edge.source_cell_id
          LEFT JOIN digital_twin_cell_states ds ON ds.cell_id = edge.target_cell_id
        )
        SELECT
          MIN(c.city_id) AS city_id,
          MIN(c.region_id)::text AS region_id,
          ARRAY_AGG(DISTINCT c.cell_id) AS controlled_cells,
          GREATEST(COUNT(*), 1)::int AS controlled_cell_count,
          GREATEST(COALESCE(SUM(c.vehicle_count), 0), 0)::double precision AS incoming_vehicle_count,
          COALESCE(AVG(c.average_speed), 0)::double precision AS avg_speed,
          LEAST(
            1.5,
            GREATEST(
              0,
              COALESCE(AVG(c.traffic_density + c.risk_score * 0.8), 0) +
              COALESCE((SELECT avg_density + avg_risk FROM adjacency), 0) * 0.35
            )
          ) AS nearby_congestion_index,
          GREATEST(COALESCE(SUM(c.road_capacity), 250), 60)::double precision / 8.0 AS saturation_flow
        FROM controlled c
      `,
      [intersectionId, cityId ?? null],
    );

    const row = aggregate.rows[0];
    if (!row?.city_id) {
      throw new Error(`intersection ${intersectionId} not found`);
    }

    const initialQueue = Math.max(0, Number(row.incoming_vehicle_count ?? 0) * 0.35);
    const state = await this.db.query<StateRow>(
      `
        INSERT INTO traffic_signal_states (
          intersection_id,
          city_id,
          region_id,
          controlled_cells,
          controlled_cell_count,
          signal_phase,
          phase_elapsed_seconds,
          phase_duration_seconds,
          min_phase_seconds,
          max_phase_seconds,
          yellow_seconds,
          queue_length,
          avg_wait_seconds,
          throughput_vehicles,
          incoming_vehicle_count,
          avg_speed,
          nearby_congestion_index,
          saturation_flow
        )
        VALUES (
          $1,
          $2,
          $3::bigint,
          $4::bigint[],
          $5::int,
          'NS_GREEN',
          0,
          $6::int,
          $7::int,
          $8::int,
          $9::int,
          $10,
          0,
          0,
          $11,
          $12,
          $13,
          $14
        )
        ON CONFLICT (intersection_id) DO UPDATE
        SET city_id = EXCLUDED.city_id,
            region_id = EXCLUDED.region_id,
            controlled_cells = EXCLUDED.controlled_cells,
            controlled_cell_count = EXCLUDED.controlled_cell_count,
            incoming_vehicle_count = EXCLUDED.incoming_vehicle_count,
            avg_speed = EXCLUDED.avg_speed,
            nearby_congestion_index = EXCLUDED.nearby_congestion_index,
            saturation_flow = EXCLUDED.saturation_flow,
            signal_phase = CASE WHEN $15::boolean THEN 'NS_GREEN' ELSE traffic_signal_states.signal_phase END,
            phase_elapsed_seconds = CASE WHEN $15::boolean THEN 0 ELSE traffic_signal_states.phase_elapsed_seconds END,
            phase_duration_seconds = CASE WHEN $15::boolean THEN EXCLUDED.phase_duration_seconds ELSE traffic_signal_states.phase_duration_seconds END,
            min_phase_seconds = CASE WHEN $15::boolean THEN EXCLUDED.min_phase_seconds ELSE traffic_signal_states.min_phase_seconds END,
            max_phase_seconds = CASE WHEN $15::boolean THEN EXCLUDED.max_phase_seconds ELSE traffic_signal_states.max_phase_seconds END,
            yellow_seconds = CASE WHEN $15::boolean THEN EXCLUDED.yellow_seconds ELSE traffic_signal_states.yellow_seconds END,
            queue_length = CASE WHEN $15::boolean THEN EXCLUDED.queue_length ELSE traffic_signal_states.queue_length END,
            avg_wait_seconds = CASE WHEN $15::boolean THEN 0 ELSE traffic_signal_states.avg_wait_seconds END,
            throughput_vehicles = CASE WHEN $15::boolean THEN 0 ELSE traffic_signal_states.throughput_vehicles END,
            updated_at = now()
        RETURNING *
      `,
      [
        intersectionId,
        row.city_id,
        row.region_id,
        row.controlled_cells ?? [],
        Number(row.controlled_cell_count ?? 1),
        this.defaultPhaseSeconds,
        this.defaultMinPhaseSeconds,
        this.defaultMaxPhaseSeconds,
        this.defaultYellowSeconds,
        initialQueue,
        Number(row.incoming_vehicle_count ?? 0),
        Number(row.avg_speed ?? 0),
        Number(row.nearby_congestion_index ?? 0),
        Number(row.saturation_flow ?? 30),
        resetControl,
      ],
    );

    return state.rows[0];
  }

  private evaluateTransition(current: StateRow, action: SignalAction, tickSeconds: number) {
    return this.simulateTransition(this.mapState(current), action, tickSeconds);
  }

  private applyAction(
    currentPhase: SignalPhase,
    currentDuration: number,
    currentElapsed: number,
    minPhaseSeconds: number,
    maxPhaseSeconds: number,
    _yellowSeconds: number,
    action: SignalAction,
    tickSeconds: number,
  ) {
    let nextPhase = currentPhase;
    let nextDurationSeconds = currentDuration;
    let nextElapsedSeconds = currentElapsed + tickSeconds;
    let validAction = true;
    let phaseSwitched = false;

    if (action === 'extend_green') {
      nextDurationSeconds = Math.min(maxPhaseSeconds, currentDuration + 5);
    } else if (action === 'shorten_phase') {
      nextDurationSeconds = Math.max(minPhaseSeconds, currentDuration - 5);
    } else if (action === 'switch_phase') {
      if (currentElapsed < minPhaseSeconds) {
        validAction = false;
      } else {
        nextPhase = this.flipPhase(currentPhase);
        nextDurationSeconds = Math.max(minPhaseSeconds, Math.min(maxPhaseSeconds, currentDuration));
        nextElapsedSeconds = 0;
        phaseSwitched = true;
      }
    } else if (action === 'hold_phase') {
      // no-op
    } else {
      validAction = false;
    }

    if (nextElapsedSeconds >= nextDurationSeconds) {
      nextPhase = this.flipPhase(nextPhase);
      nextElapsedSeconds = 0;
      phaseSwitched = true;
    }

    return {
      nextPhase,
      nextDurationSeconds,
      nextElapsedSeconds,
      validAction,
      phaseSwitched,
    };
  }

  private computeReward(previous: IntersectionAgentState, next: IntersectionAgentState, validAction: boolean) {
    const prevTravelIndex = previous.queueLength / Math.max(previous.avgSpeed, 1);
    const nextTravelIndex = next.queueLength / Math.max(next.avgSpeed, 1);
    const queueReward = Math.max(0, previous.queueLength - next.queueLength) * 1.2;
    const throughputReward = next.throughputVehicles * 0.8;
    const travelTimeReward = Math.max(0, prevTravelIndex - nextTravelIndex) * 6.0;
    const waitPenalty = next.avgWaitSeconds * 0.06;
    const spillbackPenalty = Math.max(0, next.queueLength - next.saturationFlow) * 0.4;
    const congestionPenalty = next.nearbyCongestionIndex * 1.1;
    const invalidActionPenalty = validAction ? 0 : 2.5;

    const total =
      queueReward +
      throughputReward +
      travelTimeReward -
      waitPenalty -
      spillbackPenalty -
      congestionPenalty -
      invalidActionPenalty;

    return {
      total: Number(total.toFixed(6)),
      positive: {
        reducedQueueLength: Number(queueReward.toFixed(6)),
        higherThroughput: Number(throughputReward.toFixed(6)),
        reducedTravelTime: Number(travelTimeReward.toFixed(6)),
      },
      negative: {
        longWaitTimes: Number(waitPenalty.toFixed(6)),
        spillbackCongestion: Number(spillbackPenalty.toFixed(6)),
        nearbyCongestion: Number(congestionPenalty.toFixed(6)),
        invalidAction: Number(invalidActionPenalty.toFixed(6)),
      },
    };
  }

  private async persistStep(
    intersectionId: string,
    next: IntersectionAgentState,
    episodeId: string,
    stepIndex: number,
    action: SignalAction,
    reward: {
      total: number;
      positive: Record<string, number>;
      negative: Record<string, number>;
    },
  ) {
    await this.db.query(
      `
        UPDATE traffic_signal_states
        SET
          signal_phase = $2,
          phase_elapsed_seconds = $3::int,
          phase_duration_seconds = $4::int,
          queue_length = $5,
          avg_wait_seconds = $6,
          throughput_vehicles = $7,
          incoming_vehicle_count = $8,
          avg_speed = $9,
          nearby_congestion_index = $10,
          updated_at = now()
        WHERE intersection_id = $1
      `,
      [
        intersectionId,
        next.signalPhase,
        next.phaseElapsedSeconds,
        next.phaseDurationSeconds,
        next.queueLength,
        next.avgWaitSeconds,
        next.throughputVehicles,
        next.incomingVehicleCount,
        next.avgSpeed,
        next.nearbyCongestionIndex,
      ],
    );

    await this.db.query(
      `
        INSERT INTO traffic_signal_episode_steps (
          episode_id,
          step_index,
          intersection_id,
          action,
          reward,
          state,
          next_state,
          details
        )
        VALUES ($1, $2::int, $3, $4, $5, $6::jsonb, $7::jsonb, $8::jsonb)
      `,
      [
        episodeId,
        stepIndex,
        intersectionId,
        action,
        reward.total,
        JSON.stringify({
          intersectionId: next.intersectionId,
          signalPhase: next.signalPhase,
          phaseElapsedSeconds: next.phaseElapsedSeconds,
          phaseDurationSeconds: next.phaseDurationSeconds,
        }),
        JSON.stringify(next),
        JSON.stringify(reward),
      ],
    );
  }

  private describeActionConstraints(action: SignalAction) {
    if (action === 'switch_phase') {
      return {
        requiresMinGreenElapsed: true,
        autoFlipOnTimeout: true,
      };
    }
    if (action === 'extend_green') {
      return {
        maxPhaseSeconds: this.defaultMaxPhaseSeconds,
        stepSeconds: 5,
      };
    }
    if (action === 'shorten_phase') {
      return {
        minPhaseSeconds: this.defaultMinPhaseSeconds,
        stepSeconds: 5,
      };
    }
    return {
      preservesPhase: true,
    };
  }

  private flipPhase(phase: SignalPhase): SignalPhase {
    return phase === 'NS_GREEN' ? 'EW_GREEN' : 'NS_GREEN';
  }

  private mapState(row: StateRow): IntersectionAgentState {
    return {
      intersectionId: row.intersection_id,
      incomingVehicleCount: Number(row.incoming_vehicle_count ?? 0),
      avgSpeed: Number(row.avg_speed ?? 0),
      signalPhase: row.signal_phase,
      nearbyCongestionIndex: Number(row.nearby_congestion_index ?? 0),
      queueLength: Number(row.queue_length ?? 0),
      avgWaitSeconds: Number(row.avg_wait_seconds ?? 0),
      throughputVehicles: Number(row.throughput_vehicles ?? 0),
      phaseElapsedSeconds: Number(row.phase_elapsed_seconds ?? 0),
      phaseDurationSeconds: Number(row.phase_duration_seconds ?? 0),
      minPhaseSeconds: Number(row.min_phase_seconds ?? this.defaultMinPhaseSeconds),
      maxPhaseSeconds: Number(row.max_phase_seconds ?? this.defaultMaxPhaseSeconds),
      yellowSeconds: Number(row.yellow_seconds ?? this.defaultYellowSeconds),
      saturationFlow: Number(row.saturation_flow ?? 30),
      cityId: row.city_id,
      regionId: String(row.region_id),
      controlledCellCount: Number(row.controlled_cell_count ?? 1),
    };
  }
}
