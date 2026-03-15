const test = require('node:test');
const assert = require('node:assert/strict');
const { TrafficSignalRLService } = require('../dist/src/modules/simulation/traffic-signal-rl.service');

function createTrafficSignalAI() {
  return {
    createSyntheticState(intersectionId, cityId, regionId, seed) {
      return {
        intersectionId,
        cityId,
        regionId,
        incomingVehicleCount: 24 + seed,
        avgSpeed: 28,
        signalPhase: seed % 2 === 0 ? 'NS_GREEN' : 'EW_GREEN',
        nearbyCongestionIndex: 0.55,
        queueLength: 18,
        avgWaitSeconds: 14,
        throughputVehicles: 6,
        phaseElapsedSeconds: 20,
        phaseDurationSeconds: 30,
        minPhaseSeconds: 15,
        maxPhaseSeconds: 90,
        yellowSeconds: 3,
        saturationFlow: 34,
        controlledCellCount: 2,
      };
    },
    simulateTransition(state, action) {
      const queueDelta = action === 'switch_phase' ? -4 : action === 'hold_phase' ? 2 : -1;
      const nextQueue = Math.max(0, state.queueLength + queueDelta);
      const nextSpeed = Math.max(5, state.avgSpeed + (action === 'switch_phase' ? 3 : -1));
      const reward = 20 - nextQueue - (80 - nextSpeed) * 0.1;
      return {
        validAction: true,
        nextState: {
          ...state,
          queueLength: nextQueue,
          avgSpeed: nextSpeed,
          avgWaitSeconds: Math.max(0, state.avgWaitSeconds - 1),
          throughputVehicles: state.throughputVehicles + 1,
          phaseElapsedSeconds: state.phaseElapsedSeconds + 5,
          signalPhase:
            action === 'switch_phase'
              ? state.signalPhase === 'NS_GREEN'
                ? 'EW_GREEN'
                : 'NS_GREEN'
              : state.signalPhase,
          incomingVehicleCount: Math.max(0, state.incomingVehicleCount - 1),
          nearbyCongestionIndex: Math.max(0, state.nearbyCongestionIndex - 0.02),
        },
        reward: {
          total: reward,
          positive: {
            reducedQueueLength: 5,
            higherThroughput: 3,
            reducedTravelTime: 2,
          },
          negative: {
            longWaitTimes: 1,
            spillbackCongestion: 0,
            nearbyCongestion: 1,
            invalidAction: 0,
          },
        },
      };
    },
  };
}

function createService(overrides = {}) {
  const queries = [];
  const db = {
    async query(sql, params) {
      queries.push({ sql: String(sql), params });
      return { rows: [] };
    },
    ...overrides.db,
  };
  return {
    service: new TrafficSignalRLService(
      overrides.trafficSignalAI ?? createTrafficSignalAI(),
      db,
    ),
    queries,
  };
}

test('trains a DQN controller with replay and persists the run', async () => {
  const { service, queries } = createService();
  const result = await service.trainDqn({
    city_id: 'delhi',
    episodes: 6,
    max_steps: 6,
    batch_size: 4,
    replay_capacity: 16,
  });

  assert.equal(result.algorithm, 'DQN');
  assert.equal(result.metrics.episodes, 6);
  assert.ok(result.replayBufferSize > 0);
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO traffic_signal_training_runs')));
});

test('trains a PPO controller and returns a DQN comparison', async () => {
  const { service, queries } = createService();
  const result = await service.trainPpo({
    city_id: 'delhi',
    episodes: 6,
    max_steps: 5,
    epochs: 2,
  });

  assert.equal(result.algorithm, 'PPO');
  assert.ok(['PPO', 'DQN'].includes(result.comparison.winner));
  assert.ok(
    queries.filter((entry) => entry.sql.includes('INSERT INTO traffic_signal_training_runs')).length >= 2,
  );
});
