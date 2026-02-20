const test = require('node:test');
const assert = require('node:assert/strict');
const { RiskService } = require('../dist/src/modules/risk/risk.service');

function createService(overrides = {}) {
  const db = {
    async query(text) {
      if (text.includes('FROM model_parameters')) {
        return {
          rows: [
            { key: 'SIGMOID_K', value: 20 },
            { key: 'MAX_ROUTE_VERTICES', value: 5 },
            { key: 'MAX_ROUTE_DISTANCE_KM', value: 50 },
          ],
        };
      }
      if (text.includes('calculate_route_risk_v3')) {
        return { rows: [{ risk_score: 20, event_count: 4 }] };
      }
      throw new Error(`Unexpected query: ${text}`);
    },
    ...overrides,
  };
  return new RiskService(db);
}

test('returns LOW risk for insufficient coordinates', async () => {
  const service = createService();
  const result = await service.calculateRouteRisk({
    coordinates: [{ lat: 28.61, lng: 77.2 }],
    city: 'DEL',
  });

  assert.equal(result.score, 0);
  assert.equal(result.level, 'LOW');
  assert.equal(result.eventCount, 0);
});

test('normalizes score and level from risk_cells function output', async () => {
  const service = createService();
  const result = await service.calculateRouteRisk({
    coordinates: [
      { lat: 28.61, lng: 77.2 },
      { lat: 28.62, lng: 77.21 },
    ],
    city: 'DEL',
  });

  assert.equal(result.eventCount, 4);
  assert.equal(result.level, 'MEDIUM');
  assert.equal(result.score, 0.632);
});

test('rejects route exceeding DB-configured vertex limit', async () => {
  const service = createService();
  await assert.rejects(
    () =>
      service.calculateRouteRisk({
        coordinates: [
          { lat: 28.61, lng: 77.2 },
          { lat: 28.62, lng: 77.21 },
          { lat: 28.63, lng: 77.22 },
          { lat: 28.64, lng: 77.23 },
          { lat: 28.65, lng: 77.24 },
          { lat: 28.66, lng: 77.25 },
        ],
        city: 'DEL',
      }),
    /Route too complex/,
  );
});
