const test = require('node:test');
const assert = require('node:assert/strict');
const { SpatialRiskFieldService } = require('../dist/src/modules/risk/spatial-risk-field.service');

function createService({ observedAt } = {}) {
  const persisted = [];
  let replaced = null;
  const db = {
    async queryRead(sql) {
      const statement = String(sql);
      if (statement.includes('FROM regional_geo_events_v')) {
        return {
          rows: [
            {
              event_id: 'evt-1',
              h3_cell: '8928308280fffff',
              severity: 4,
              confidence: 0.8,
              observed_at: observedAt ?? new Date().toISOString(),
            },
          ],
        };
      }
      if (statement.includes('FROM model_parameters')) {
        return {
          rows: [
            { key: 'TEMPORAL_TAU_SECONDS', value: 3600 },
            { key: 'DIFFUSION_ROUNDS', value: 1 },
          ],
        };
      }
      return { rows: [] };
    },
    async withTransaction(operation) {
      await operation({
        async query(sql, params) {
          persisted.push({ sql: String(sql), params });
          return { rows: [] };
        },
      });
    },
  };

  const spatial = {
    getInfluenceNeighbors() {
      return ['8928308280fffff', '8928308280bffff'];
    },
    getGridDistance(origin, destination) {
      return origin === destination ? 0 : 1;
    },
    getInfluenceWeight(distance) {
      return distance === 0 ? 1 : 0.5;
    },
    toDbIndex(cell) {
      return cell === '8928308280fffff' ? '1001' : '1002';
    },
  };

  const riskGrid = {
    replaceAll(next) {
      replaced = next;
    },
  };

  const cache = {
    async replaceSurface() {},
  };

  return {
    service: new SpatialRiskFieldService(db, spatial, riskGrid, cache),
    persisted,
    getReplaced: () => replaced,
  };
}

test('materializes res9 event influence into risk_cells with diffusion', async () => {
  const { service, persisted, getReplaced } = createService();
  const stats = await service.refreshRiskField();

  assert.equal(stats.eventCount, 1);
  assert.equal(stats.cellCount, 2);

  const weights = getReplaced();
  assert.ok(weights instanceof Map);
  assert.ok(weights.get('8928308280fffff') > weights.get('8928308280bffff'));

  const insert = persisted.find((entry) => entry.sql.includes('INSERT INTO risk_cells'));
  assert.ok(insert);
  assert.deepEqual(insert.params[0], ['1001', '1002']);
});

test('applies exponential temporal decay before diffusion', async () => {
  const fresh = createService();
  const stale = createService({
    observedAt: new Date(Date.now() - (2 * 3600 * 1000)).toISOString(),
  });

  await fresh.service.refreshRiskField();
  await stale.service.refreshRiskField();

  const freshWeight = fresh.getReplaced().get('8928308280fffff');
  const staleWeight = stale.getReplaced().get('8928308280fffff');
  assert.ok(staleWeight < freshWeight);
});
