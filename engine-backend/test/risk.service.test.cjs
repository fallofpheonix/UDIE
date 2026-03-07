const test = require('node:test');
const assert = require('node:assert/strict');
const { RiskService } = require('../dist/src/modules/risk/risk.service');

function createService(weightMap = new Map()) {
  const inMemRisk = {
    getWeight(h3Index) {
      return weightMap.get(h3Index) ?? 0;
    },
  };

  const spatial = {
    getInfluenceNeighbors(cell) {
      return [cell];
    },
    getGridDistance() {
      return 0;
    },
    getInfluenceWeight() {
      return 1;
    },
  };

  const observability = {
    observeRiskEvalLatency() {},
  };

  return new RiskService(inMemRisk, spatial, observability);
}

test('returns zeroed response for insufficient route coverage', async () => {
  const service = createService();
  const result = await service.calculateRouteRisk({
    coordinates: [{ lat: 28.61, lng: 77.2 }],
  });

  assert.equal(result.riskScore, 0);
  assert.equal(result.riskDensity, 0);
  assert.equal(result.routeLengthKm, 0);
});

test('returns positive risk score when weighted cells are present', async () => {
  const h3 = require('h3-js');
  const c1 = h3.latLngToCell(28.61, 77.2, 9);
  const c2 = h3.latLngToCell(28.62, 77.21, 9);

  const map = new Map();
  map.set(c1, 8);
  map.set(c2, 6);

  const service = createService(map);
  const result = await service.calculateRouteRisk({
    coordinates: [
      { lat: 28.61, lng: 77.2 },
      { lat: 28.62, lng: 77.21 },
    ],
  });

  assert.ok(result.riskScore > 0);
  assert.ok(result.cellCount >= 1);
  assert.ok(result.latencyMs >= 0);
});
