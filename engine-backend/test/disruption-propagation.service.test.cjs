const test = require('node:test');
const assert = require('node:assert/strict');
const { DisruptionPropagationService } = require('../dist/src/modules/simulation/disruption-propagation.service');

function createService(overrides = {}) {
  const queries = [];
  const db = {
    async withTransaction(operation) {
      return operation({
        async query(sql, params) {
          queries.push({ sql: String(sql), params });
          return { rows: [] };
        },
      });
    },
    async queryRead(sql, params) {
      queries.push({ sql: String(sql), params });
      return {
        rows: [
          { cell_id: '8928308280fffff', influence_weight: 0.8, distance_k: 0 },
          { cell_id: '8928308280bffff', influence_weight: 0.24, distance_k: 1 },
        ],
      };
    },
    ...overrides.db,
  };

  const spatial = {
    getH3Index() {
      return '8928308280fffff';
    },
    getRegionId() {
      return '617700169958293503';
    },
    getInfluenceNeighbors() {
      return ['8928308280fffff', '8928308280bffff'];
    },
    getGridDistance(origin, destination) {
      return origin === destination ? 0 : 1;
    },
    toDbIndex(cell) {
      return cell === '8928308280fffff' ? '1001' : '1002';
    },
    ...overrides.spatial,
  };

  return {
    service: new DisruptionPropagationService(db, spatial),
    queries,
  };
}

test('creates disruption records with propagated influence cells', async () => {
  const { service, queries } = createService();
  const result = await service.createDisruption({
    type: 'ACCIDENT',
    lat: 28.6139,
    lng: 77.209,
    start_time: '2026-03-15T10:00:00.000Z',
    severity: 4,
    estimated_duration_minutes: 45,
    affected_roads: ['ring-road'],
    kernel: 'EXPONENTIAL',
  });

  assert.equal(result.type, 'ACCIDENT');
  assert.ok(result.propagatedCells >= 1);
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO simulation_disruptions')));
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO disruption_influence_cells')));
});

test('lists persisted disruption influence cells', async () => {
  const { service } = createService();
  const result = await service.listInfluence('11111111-1111-1111-1111-111111111111');
  assert.equal(result.cells.length, 2);
  assert.ok(result.cells[0].influenceWeight >= result.cells[1].influenceWeight);
});
