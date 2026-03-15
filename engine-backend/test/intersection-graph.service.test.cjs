const test = require('node:test');
const assert = require('node:assert/strict');
const { IntersectionGraphService } = require('../dist/src/modules/simulation/intersection-graph.service');

test('builds an intersection graph with capacity, length, and speed limit edges', async () => {
  const service = new IntersectionGraphService({
    async query() {
      return {
        rows: [
          {
            source_intersection: 'ix-1',
            target_intersection: 'ix-2',
            capacity: 320,
            length_meters: 450,
            speed_limit: 42,
          },
        ],
      };
    },
    async queryRead() {
      return { rows: [] };
    },
  });

  const result = await service.buildGraph({ city_id: 'delhi' });
  assert.equal(result.edgeCount, 1);
  assert.equal(result.edges[0].capacity, 320);
  assert.equal(result.edges[0].lengthMeters, 450);
  assert.equal(result.edges[0].speedLimit, 42);
});
