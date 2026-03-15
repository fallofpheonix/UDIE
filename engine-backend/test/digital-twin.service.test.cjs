const test = require('node:test');
const assert = require('node:assert/strict');
const { DigitalTwinService } = require('../dist/src/modules/simulation/digital-twin.service');

function createService(overrides = {}) {
  const operations = [];
  const db = {
    async withTransaction(operation) {
      return operation({
        async query(sql, params) {
          const statement = String(sql);
          operations.push({ sql: statement, params });

          if (statement.includes('FROM risk_cells')) {
            return { rows: [{ risk_score: 1.4 }] };
          }
          if (statement.includes('FROM city_grid_cells cg')) {
            return {
              rows: [{
                cell_id: '8928308280fffff',
                city_id: 'delhi',
                region_id: '617700169958293503',
                center_lat: 28.6139,
                center_lng: 77.209,
                road_segments: ['ring-road'],
                intersection_ids: ['ix-1'],
              }],
            };
          }
          return { rows: [] };
        },
      });
    },
    async queryRead(sql, params) {
      operations.push({ sql: String(sql), params });
      return {
        rows: [{
          cell_id: '8928308280fffff',
          city_id: 'delhi',
          region_id: '617700169958293503',
          center_lat: 28.6139,
          center_lng: 77.209,
          road_segments: ['ring-road'],
          intersection_ids: ['ix-1'],
          traffic_density: 0.82,
          average_speed: 21,
          disruption_weight: 0.67,
          risk_score: 0.5,
          vehicle_count: 42,
          timestamp: '2026-03-15T09:00:00.000Z',
        }],
      };
    },
    async query(sql, params) {
      operations.push({ sql: String(sql), params });
      return { rows: [] };
    },
    ...overrides.db,
  };

  const spatial = {
    getCoveringCells() {
      return ['8928308280fffff', '8928308280bffff'];
    },
    getCellCenter(cell) {
      return cell === '8928308280fffff' ? [28.6139, 77.209] : [28.615, 77.211];
    },
    getCellParent() {
      return '86283082fffffff';
    },
    getCellNeighbors() {
      return ['8928308280fffff', '8928308280bffff'];
    },
    getH3Index() {
      return '8928308280fffff';
    },
    getRegionId() {
      return '617700169958293503';
    },
    toDbIndex(cell) {
      return cell === '8928308280fffff' ? '1001' : cell === '8928308280bffff' ? '1002' : '9001';
    },
    ...overrides.spatial,
  };

  const stateStore = {
    async getCells(cells) {
      return new Map(cells.map((cell) => [cell, {
        cellId: cell,
        regionId: '617700169958293503',
        trafficDensity: 0.82,
        averageSpeed: 21,
        disruptionWeight: 0.67,
        riskScore: 0.5,
        vehicleCount: 42,
        timestamp: '2026-03-15T09:00:00.000Z',
      }]));
    },
    async upsert() {},
    async upsertMany() {},
    ...overrides.stateStore,
  };

  return {
    service: new DigitalTwinService(db, spatial, stateStore),
    operations,
  };
}

test('bootstraps city metadata on res9 cells and res6 shard ids', async () => {
  const { service, operations } = createService();
  const result = await service.bootstrapGrid({
    city_id: 'delhi',
    minLat: 28.5,
    minLng: 77.1,
    maxLat: 28.7,
    maxLng: 77.3,
    resolution: 9,
  });

  assert.equal(result.cityId, 'delhi');
  assert.equal(result.cellCount, 2);
  assert.equal(result.regionCount, 1);

  const insert = operations.find((entry) => entry.sql.includes('INSERT INTO city_grid_cells'));
  assert.ok(insert);
  assert.deepEqual(insert.params[0], ['1001', '1002']);
  assert.deepEqual(insert.params[2], ['9001', '9001']);

  const edges = operations.find((entry) => entry.sql.includes('INSERT INTO city_grid_edges'));
  assert.ok(edges);
});

test('upserts digital twin state and clamps risk score below 1.0', async () => {
  const upserts = [];
  const { service, operations } = createService({
    stateStore: {
      async upsert(state) {
        upserts.push(state);
      },
      async getCells() {
        return new Map();
      },
      async upsertMany() {},
    },
  });
  const result = await service.upsertCellState({
    city_id: 'delhi',
    lat: 28.6139,
    lng: 77.209,
    traffic_density: 0.82,
    average_speed: 21,
    disruption_weight: 0.67,
    vehicle_count: 42,
    road_segments: ['ring-road'],
    intersection_ids: ['ix-1'],
  });

  assert.equal(result.cellId, '8928308280fffff');
  assert.equal(result.state.riskScore, 0.999999);
  assert.equal(upserts[0].riskScore, 0.999999);

  assert.ok(operations.some((entry) => entry.sql.includes('INSERT INTO digital_twin_cell_states')));
  assert.ok(operations.some((entry) => entry.sql.includes('INSERT INTO digital_twin_cell_state_history')));
});

test('queries viewport cells via covering-cell filter instead of global scans', async () => {
  const { service, operations } = createService();
  const result = await service.listCellsForViewport({
    city_id: 'delhi',
    minLat: 28.5,
    minLng: 77.1,
    maxLat: 28.7,
    maxLng: 77.3,
    limit: 500,
  });

  assert.equal(result.cells.length, 1);
  assert.equal(result.cells[0].cellId, '8928308280fffff');
  assert.equal(result.cells[0].state.riskScore, 0.5);

  const query = operations.find((entry) => entry.sql.includes('WHERE cg.city_id = $1'));
  assert.ok(query);
  assert.deepEqual(query.params[1], ['1001', '1002']);
});

test('returns bounded cell history from snapshots and ingest transitions', async () => {
  const { service } = createService({
    db: {
      async queryRead() {
        return {
          rows: [
            {
              source: 'snapshot',
              timestamp: '2026-03-15T09:00:00.000Z',
              traffic_density: 0.7,
              average_speed: 24,
              disruption_weight: 0.4,
              risk_score: 0.35,
              vehicle_count: 30,
            },
            {
              source: 'ingest',
              timestamp: '2026-03-15T08:58:00.000Z',
              traffic_density: 0.5,
              average_speed: 28,
              disruption_weight: 0.2,
              risk_score: 0.18,
              vehicle_count: 22,
            },
          ],
        };
      },
    },
  });

  const result = await service.getCellHistory('8928308280fffff', { limit: 10 });
  assert.equal(result.transitions.length, 2);
  assert.equal(result.transitions[0].source, 'snapshot');
});
