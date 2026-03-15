const test = require('node:test');
const assert = require('node:assert/strict');
const { IntersectionCoordinationService } = require('../dist/src/modules/simulation/intersection-coordination.service');

function createService(overrides = {}) {
  const db = {
    async queryRead() {
      return {
        rows: [
          {
            source_intersection_id: 'ix-1',
            target_intersection_id: 'ix-2',
            queue_length: 24,
            arrival_rate: 8,
            congestion_index: 0.9,
          },
          {
            source_intersection_id: 'ix-2',
            target_intersection_id: 'ix-3',
            queue_length: 8,
            arrival_rate: 3,
            congestion_index: 0.3,
          },
        ],
      };
    },
    ...overrides.db,
  };

  const trafficSignalAI = {
    async getIntersectionAgent(intersectionId) {
      return {
        agent: {
          intersectionId,
          phaseElapsedSeconds: 18,
          minPhaseSeconds: 15,
        },
      };
    },
    ...overrides.trafficSignalAI,
  };

  return new IntersectionCoordinationService(db, trafficSignalAI);
}

test('coordinates agents using exchanged queue, inflow, and congestion messages', async () => {
  const service = createService();
  const result = await service.coordinate('delhi');

  assert.equal(result.coordinatedActions.length, 2);
  assert.equal(result.coordinatedActions[0].intersectionId, 'ix-1');
  assert.equal(result.coordinatedActions[0].action, 'extend_green');
  assert.ok(result.coordinatedActions[0].exchangedState.congestionLevel > 0.8);
});
