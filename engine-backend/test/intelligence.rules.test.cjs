const test = require('node:test');
const assert = require('node:assert/strict');
const {
  hotspotInsight,
  spikeInsight,
  recurringInsight,
} = require('../dist/src/intelligence/IntelligenceRules');

const config = {
  hotspotThreshold: 8,
  hotspotNeighborCount: 3,
  recurringThreshold24h: 5,
  spikeMultiplier: 3,
  spikeWindowMinutes: 10,
  scanLimit: 500,
};

test('hotspot rule emits HOTSPOT when threshold and neighbor conditions hold', () => {
  const insight = hotspotInsight('8965a2cffffffff', 12, 4, config);
  assert.ok(insight);
  assert.equal(insight.type, 'HOTSPOT');
});

test('spike rule emits SUDDEN_SPIKE when increase exceeds 200%', () => {
  const insight = spikeInsight('8965a2cffffffff', 2, 7, config);
  assert.ok(insight);
  assert.equal(insight.type, 'SUDDEN_SPIKE');
});

test('recurring rule emits RECURRING_EVENT when count > threshold', () => {
  const insight = recurringInsight('8965a2cffffffff', 6, config);
  assert.ok(insight);
  assert.equal(insight.type, 'RECURRING_EVENT');
});
