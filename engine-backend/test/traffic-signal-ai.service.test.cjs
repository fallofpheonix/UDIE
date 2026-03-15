const test = require('node:test');
const assert = require('node:assert/strict');
const { TrafficSignalAIService } = require('../dist/src/modules/simulation/traffic-signal-ai.service');

function createService(overrides = {}) {
  const queries = [];
  const db = {
    async queryRead(sql, params) {
      const statement = String(sql);
      queries.push({ sql: statement, params });

      if (statement.includes('SELECT DISTINCT jsonb_array_elements_text')) {
        return { rows: [{ intersection_id: 'ix-1' }, { intersection_id: 'ix-2' }] };
      }

      if (statement.includes('WITH controlled AS')) {
        return {
          rows: [{
            city_id: 'delhi',
            region_id: '617700169958293503',
            controlled_cells: ['1001', '1002'],
            controlled_cell_count: 2,
            incoming_vehicle_count: 44,
            avg_speed: 22,
            nearby_congestion_index: 0.72,
            saturation_flow: 36,
          }],
        };
      }

      return { rows: [] };
    },
    async query(sql, params) {
      const statement = String(sql);
      queries.push({ sql: statement, params });

      if (statement.includes('INSERT INTO traffic_signal_states')) {
        return {
          rows: [{
            intersection_id: params[0],
            city_id: 'delhi',
            region_id: '617700169958293503',
            controlled_cells: ['1001', '1002'],
            controlled_cell_count: 2,
            signal_phase: 'NS_GREEN',
            phase_elapsed_seconds: params[14] ? 0 : 12,
            phase_duration_seconds: 30,
            min_phase_seconds: 15,
            max_phase_seconds: 90,
            yellow_seconds: 3,
            queue_length: params[9],
            avg_wait_seconds: 8,
            throughput_vehicles: 6,
            incoming_vehicle_count: 44,
            avg_speed: 22,
            nearby_congestion_index: 0.72,
            saturation_flow: 36,
          }],
        };
      }

      return { rows: [] };
    },
    ...overrides.db,
  };

  return {
    service: new TrafficSignalAIService(db),
    queries,
  };
}

test('hydrates an intersection agent from digital twin aggregates', async () => {
  const { service, queries } = createService();
  const result = await service.getIntersectionAgent('ix-1', 'delhi');

  assert.equal(result.agent.intersectionId, 'ix-1');
  assert.equal(result.agent.incomingVehicleCount, 44);
  assert.equal(result.agent.avgSpeed, 22);
  assert.equal(result.agent.signalPhase, 'NS_GREEN');
  assert.ok(queries.some((entry) => entry.sql.includes('WITH controlled AS')));
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO traffic_signal_states')));
});

test('resets a deterministic RL environment for discovered intersections', async () => {
  const { service } = createService();
  const result = await service.resetEnvironment({ city_id: 'delhi', limit: 2 });

  assert.equal(typeof result.episodeId, 'string');
  assert.equal(result.intersections.length, 2);
  assert.deepEqual(result.actionSpace, ['extend_green', 'switch_phase', 'shorten_phase', 'hold_phase']);
});

test('steps the environment, enforces signal constraints, and logs rewards', async () => {
  const persisted = [];
  const { service } = createService({
    db: {
      async query(sql, params) {
        const statement = String(sql);
        persisted.push({ sql: statement, params });
        if (statement.includes('INSERT INTO traffic_signal_states')) {
          return {
            rows: [{
              intersection_id: 'ix-1',
              city_id: 'delhi',
              region_id: '617700169958293503',
              controlled_cells: ['1001', '1002'],
              controlled_cell_count: 2,
              signal_phase: 'NS_GREEN',
              phase_elapsed_seconds: 12,
              phase_duration_seconds: 30,
              min_phase_seconds: 15,
              max_phase_seconds: 90,
              yellow_seconds: 3,
              queue_length: 20,
              avg_wait_seconds: 10,
              throughput_vehicles: 4,
              incoming_vehicle_count: 40,
              avg_speed: 18,
              nearby_congestion_index: 0.8,
              saturation_flow: 36,
            }],
          };
        }
        return { rows: [] };
      },
    },
  });

  const result = await service.stepEnvironment({
    episode_id: 'ep-1',
    step_index: 4,
    tick_seconds: 5,
    actions: [{ intersection_id: 'ix-1', action: 'switch_phase' }],
  });

  assert.equal(result.transitions.length, 1);
  assert.equal(result.transitions[0].validAction, false);
  assert.ok(result.transitions[0].reward.negative.invalidAction > 0);
  assert.ok(persisted.some((entry) => entry.sql.includes('UPDATE traffic_signal_states')));
  assert.ok(persisted.some((entry) => entry.sql.includes('INSERT INTO traffic_signal_episode_steps')));
});
