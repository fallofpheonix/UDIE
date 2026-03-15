import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { DatabaseService } from '../../database/database.service';
import { TrainDqnDto } from './dto/train-dqn.dto';
import { TrainPpoDto } from './dto/train-ppo.dto';
import { TrafficSignalAIService } from './traffic-signal-ai.service';
import { IntersectionAgentState, signalActions } from './traffic-signal.types';

type ReplayItem = {
  state: IntersectionAgentState;
  actionIndex: number;
  reward: number;
  nextState: IntersectionAgentState;
};

@Injectable()
export class TrafficSignalRLService {
  private readonly featureCount = 9;
  private readonly gamma = 0.94;
  private readonly dqnLearningRate = 0.015;
  private readonly ppoPolicyLearningRate = 0.01;
  private readonly ppoValueLearningRate = 0.02;
  private readonly epsilonFloor = 0.08;
  private readonly ppoClip = 0.2;
  private readonly tickSeconds = 5;

  constructor(
    private readonly trafficSignalAI: TrafficSignalAIService,
    private readonly db: DatabaseService,
  ) {}

  async trainDqn(dto: TrainDqnDto) {
    const runId = randomUUID();
    const weights = this.createMatrix(signalActions.length, this.featureCount);
    const targetWeights = this.cloneMatrix(weights);
    const replay: ReplayItem[] = [];
    const episodeRewards: number[] = [];
    let epsilon = 1.0;

    for (let episode = 0; episode < dto.episodes; episode++) {
      let state = this.trafficSignalAI.createSyntheticState(
        `dqn-${episode}`,
        dto.city_id ?? 'sim-city',
        '0',
        episode + 1,
      );
      let totalReward = 0;

      for (let step = 0; step < dto.max_steps; step++) {
        const features = this.encodeState(state);
        const actionIndex = this.selectDqnAction(weights, features, epsilon);
        const transition = this.trafficSignalAI.simulateTransition(
          state,
          signalActions[actionIndex],
          this.tickSeconds,
        );
        replay.push({
          state,
          actionIndex,
          reward: transition.reward.total,
          nextState: transition.nextState,
        });
        if (replay.length > dto.replay_capacity) {
          replay.shift();
        }
        totalReward += transition.reward.total;
        state = transition.nextState;

        if (replay.length >= dto.batch_size) {
          this.trainDqnBatch(weights, targetWeights, replay.slice(replay.length - dto.batch_size));
        }
      }

      if ((episode + 1) % 4 === 0) {
        this.copyMatrix(weights, targetWeights);
      }
      epsilon = Math.max(this.epsilonFloor, epsilon * 0.92);
      episodeRewards.push(Number(totalReward.toFixed(6)));
    }

    const metrics = this.summarizeTraining(episodeRewards);
    await this.persistRun(runId, 'DQN', dto, metrics, {
      episodeRewards,
      replaySize: replay.length,
      model: { weights },
    });
    return {
      runId,
      algorithm: 'DQN',
      metrics,
      replayBufferSize: replay.length,
      epsilon: Number(epsilon.toFixed(6)),
      model: { actionWeights: weights },
    };
  }

  async trainPpo(dto: TrainPpoDto) {
    const runId = randomUUID();
    const policyWeights = this.createMatrix(signalActions.length, this.featureCount);
    const valueWeights = new Array(this.featureCount).fill(0);
    const episodeRewards: number[] = [];

    for (let episode = 0; episode < dto.episodes; episode++) {
      let state = this.trafficSignalAI.createSyntheticState(
        `ppo-${episode}`,
        dto.city_id ?? 'sim-city',
        '0',
        1000 + episode,
      );
      const trajectory: Array<{
        state: IntersectionAgentState;
        actionIndex: number;
        reward: number;
        oldProb: number;
        value: number;
      }> = [];
      let totalReward = 0;

      for (let step = 0; step < dto.max_steps; step++) {
        const features = this.encodeState(state);
        const { probs } = this.softmaxPolicy(policyWeights, features);
        const actionIndex = this.sampleAction(probs, episode, step);
        const value = this.dot(valueWeights, features);
        const transition = this.trafficSignalAI.simulateTransition(
          state,
          signalActions[actionIndex],
          this.tickSeconds,
        );
        trajectory.push({
          state,
          actionIndex,
          reward: transition.reward.total,
          oldProb: probs[actionIndex],
          value,
        });
        totalReward += transition.reward.total;
        state = transition.nextState;
      }

      const returns = this.discountedReturns(trajectory.map((entry) => entry.reward), this.gamma);
      const advantages = returns.map((ret, index) => ret - trajectory[index].value);

      for (let epoch = 0; epoch < dto.epochs; epoch++) {
        for (let index = 0; index < trajectory.length; index++) {
          const sample = trajectory[index];
          const features = this.encodeState(sample.state);
          const { probs } = this.softmaxPolicy(policyWeights, features);
          const ratio = probs[sample.actionIndex] / Math.max(sample.oldProb, 1e-6);
          const unclipped = ratio * advantages[index];
          const clippedRatio = Math.max(1 - this.ppoClip, Math.min(1 + this.ppoClip, ratio));
          const clipped = clippedRatio * advantages[index];
          const policyScale = unclipped <= clipped ? advantages[index] : 0;
          this.updatePolicy(policyWeights, features, sample.actionIndex, policyScale);
          this.updateValue(valueWeights, features, returns[index]);
        }
      }

      episodeRewards.push(Number(totalReward.toFixed(6)));
    }

    const metrics = this.summarizeTraining(episodeRewards);
    const dqnBaseline = await this.trainDqn({
      city_id: dto.city_id,
      episodes: Math.max(4, Math.floor(dto.episodes / 2)),
      max_steps: dto.max_steps,
      batch_size: 8,
      replay_capacity: 64,
    });
    const comparison = {
      ppoAverageReward: metrics.averageReward,
      dqnAverageReward: dqnBaseline.metrics.averageReward,
      winner: metrics.averageReward >= dqnBaseline.metrics.averageReward ? 'PPO' : 'DQN',
      rewardDelta: Number((metrics.averageReward - dqnBaseline.metrics.averageReward).toFixed(6)),
    };

    await this.persistRun(runId, 'PPO', dto, metrics, {
      episodeRewards,
      comparison,
      model: { policyWeights, valueWeights },
    });
    return {
      runId,
      algorithm: 'PPO',
      metrics,
      comparison,
      model: { policyWeights, valueWeights },
    };
  }

  private trainDqnBatch(weights: number[][], targetWeights: number[][], batch: ReplayItem[]) {
    for (const item of batch) {
      const features = this.encodeState(item.state);
      const nextFeatures = this.encodeState(item.nextState);
      const qValues = weights.map((row) => this.dot(row, features));
      const nextTarget = Math.max(...targetWeights.map((row) => this.dot(row, nextFeatures)));
      const tdTarget = item.reward + this.gamma * nextTarget;
      const tdError = tdTarget - qValues[item.actionIndex];
      for (let featureIndex = 0; featureIndex < features.length; featureIndex++) {
        weights[item.actionIndex][featureIndex] +=
          this.dqnLearningRate * tdError * features[featureIndex];
      }
    }
  }

  private updatePolicy(weights: number[][], features: number[], actionIndex: number, advantage: number) {
    const { probs } = this.softmaxPolicy(weights, features);
    for (let action = 0; action < weights.length; action++) {
      const baseline = action === actionIndex ? 1 : 0;
      const gradientScale = this.ppoPolicyLearningRate * advantage * (baseline - probs[action]);
      for (let featureIndex = 0; featureIndex < features.length; featureIndex++) {
        weights[action][featureIndex] += gradientScale * features[featureIndex];
      }
    }
  }

  private updateValue(weights: number[], features: number[], target: number) {
    const prediction = this.dot(weights, features);
    const error = target - prediction;
    for (let index = 0; index < features.length; index++) {
      weights[index] += this.ppoValueLearningRate * error * features[index];
    }
  }

  private encodeState(state: IntersectionAgentState) {
    return [
      1,
      Math.min(state.incomingVehicleCount / 120, 1.5),
      Math.min(state.avgSpeed / 80, 1),
      Math.min(state.nearbyCongestionIndex / 1.5, 1),
      Math.min(state.queueLength / 120, 1.5),
      Math.min(state.avgWaitSeconds / 180, 1.5),
      Math.min(state.phaseElapsedSeconds / Math.max(state.phaseDurationSeconds, 1), 1),
      state.signalPhase === 'NS_GREEN' ? 1 : 0,
      Math.min(state.saturationFlow / 80, 1.5),
    ];
  }

  private selectDqnAction(weights: number[][], features: number[], epsilon: number) {
    const score = (features[1] * 13 + features[4] * 17 + features[5] * 19 + features[6] * 23) % 1;
    if (score < epsilon) {
      return Math.floor((features[3] * 1000 + features[4] * 100) % signalActions.length);
    }
    const qValues = weights.map((row) => this.dot(row, features));
    let best = 0;
    for (let i = 1; i < qValues.length; i++) {
      if (qValues[i] > qValues[best]) {
        best = i;
      }
    }
    return best;
  }

  private sampleAction(probs: number[], episode: number, step: number) {
    const r = (((episode + 1) * 104729 + (step + 1) * 130363) % 1000) / 1000;
    let cumulative = 0;
    for (let index = 0; index < probs.length; index++) {
      cumulative += probs[index];
      if (r <= cumulative) {
        return index;
      }
    }
    return probs.length - 1;
  }

  private softmaxPolicy(weights: number[][], features: number[]) {
    const logits = weights.map((row) => this.dot(row, features));
    const max = Math.max(...logits);
    const exp = logits.map((value) => Math.exp(value - max));
    const denom = exp.reduce((sum, value) => sum + value, 0);
    return {
      probs: exp.map((value) => value / Math.max(denom, 1e-9)),
    };
  }

  private discountedReturns(rewards: number[], gamma: number) {
    const returns = new Array(rewards.length).fill(0);
    let acc = 0;
    for (let i = rewards.length - 1; i >= 0; i--) {
      acc = rewards[i] + gamma * acc;
      returns[i] = acc;
    }
    return returns;
  }

  private summarizeTraining(episodeRewards: number[]) {
    const total = episodeRewards.reduce((sum, value) => sum + value, 0);
    const average = total / Math.max(episodeRewards.length, 1);
    const best = Math.max(...episodeRewards);
    const worst = Math.min(...episodeRewards);
    return {
      episodes: episodeRewards.length,
      averageReward: Number(average.toFixed(6)),
      bestReward: Number(best.toFixed(6)),
      worstReward: Number(worst.toFixed(6)),
      finalReward: Number(episodeRewards[episodeRewards.length - 1].toFixed(6)),
    };
  }

  private async persistRun(
    runId: string,
    algorithm: 'DQN' | 'PPO',
    config: object,
    metrics: object,
    payload: object,
  ) {
    await this.db.query(
      `
        INSERT INTO traffic_signal_training_runs (
          run_id,
          algorithm,
          config,
          metrics,
          payload
        )
        VALUES ($1, $2, $3::jsonb, $4::jsonb, $5::jsonb)
      `,
      [runId, algorithm, JSON.stringify(config), JSON.stringify(metrics), JSON.stringify(payload)],
    );
  }

  private createMatrix(rows: number, cols: number) {
    return Array.from({ length: rows }, (_, row) =>
      Array.from({ length: cols }, (_, col) => ((row + 1) * (col + 3) % 17) * 0.001),
    );
  }

  private cloneMatrix(matrix: number[][]) {
    return matrix.map((row) => [...row]);
  }

  private copyMatrix(source: number[][], target: number[][]) {
    for (let i = 0; i < source.length; i++) {
      for (let j = 0; j < source[i].length; j++) {
        target[i][j] = source[i][j];
      }
    }
  }

  private dot(weights: number[], features: number[]) {
    let sum = 0;
    for (let i = 0; i < features.length; i++) {
      sum += weights[i] * features[i];
    }
    return sum;
  }
}
