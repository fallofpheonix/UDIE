const test = require('node:test');
const assert = require('node:assert/strict');
const { IngestionService } = require('../dist/src/modules/ingestion/ingestion.service');

function createService(overrides = {}) {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push(String(sql));
      if (String(sql).includes('INSERT INTO events_log')) {
        return { rows: [{ id: 'log-1' }] };
      }
      if (String(sql).includes('INSERT INTO regional_events_log')) {
        return { rows: [] };
      }
      return { rows: [] };
    },
  };

  const db = {
    async withTransaction(operation) {
      return operation(client);
    },
    async query() {
      return { rows: [{ exists: false }] };
    },
    ...overrides.db,
  };

  const parser = {
    async parse() {
      return null;
    },
    ...overrides.parser,
  };

  const spatial = {
    getRegionId() {
      return '617700169958293503';
    },
    getH3Index() {
      return '8960145ac13ffff';
    },
    toDbIndex() {
      return '617700169958293503';
    },
    ...overrides.spatial,
  };

  const partitionManager = {
    async ensurePartition() { },
    ...overrides.partitionManager,
  };

  const credibility = {
    async calculateScore() {
      return 0.84;
    },
    ...overrides.credibility,
  };

  const adversarial = {
    async isAdversarial() {
      return { blocked: false };
    },
    ...overrides.adversarial,
  };

  const bloomDedup = {
    async isProbableDuplicate() {
      return false;
    },
    remember() { },
    ...overrides.bloomDedup,
  };

  return {
    service: new IngestionService(
      db,
      parser,
      spatial,
      partitionManager,
      credibility,
      adversarial,
      bloomDedup,
    ),
    queries,
  };
}

test('rejects signals outside nationwide bounds', async () => {
  const { service } = createService();
  const result = await service.processRawEvent({
    source_id: 'sensor-1',
    source_type: 'traffic_sensor',
    lat: 51.5,
    lng: -0.12,
    event_type: 'ACCIDENT',
  });

  assert.equal(result.status, 'REJECTED');
  assert.equal(result.reason, 'OUT_OF_BOUNDS');
});

test('suppresses duplicates when bloom filter confirms an existing idempotency key', async () => {
  const { service } = createService({
    bloomDedup: {
      async isProbableDuplicate() {
        return true;
      },
      remember() { },
    },
  });

  const result = await service.processRawEvent({
    source_id: 'sensor-2',
    source_type: 'traffic_sensor',
    lat: 28.6139,
    lng: 77.2090,
    event_type: 'ACCIDENT',
  });

  assert.equal(result.status, 'DUPLICATE');
  assert.equal(result.reason, 'BLOOM_SUPPRESSED_DUPLICATE');
});

test('writes valid signals to events_log and the derived regional log without touching risk_cells', async () => {
  const { service, queries } = createService();
  const result = await service.processRawEvent({
    source_id: 'sensor-3',
    source_type: 'traffic_sensor',
    lat: 28.6139,
    lng: 77.2090,
    event_type: 'ACCIDENT',
    severity_hint: 5,
    confidence_hint: 0.9,
    text: 'lane blocked',
    transport: 'REST',
  });

  assert.equal(result.status, 'SUCCESS');
  assert.ok(queries.some((sql) => sql.includes('INSERT INTO events_log')));
  assert.ok(queries.some((sql) => sql.includes('INSERT INTO regional_events_log')));
  assert.ok(!queries.some((sql) => sql.includes('risk_cells')));
});

test('uses a stable idempotency key for replayed signals without observedAt', async () => {
  const seenKeys = new Set();
  const { service } = createService({
    db: {
      async withTransaction(operation) {
        return operation({
          async query(sql, params) {
            if (String(sql).includes('INSERT INTO events_log')) {
              const key = params[2];
              if (seenKeys.has(key)) {
                const error = new Error('duplicate');
                error.code = '23505';
                throw error;
              }
              seenKeys.add(key);
              return { rows: [{ id: `log-${seenKeys.size}` }] };
            }
            return { rows: [] };
          },
        });
      },
    },
  });

  const payload = {
    source_id: 'sensor-stable-1',
    source_type: 'traffic_sensor',
    lat: 28.6139,
    lng: 77.2090,
    event_type: 'ACCIDENT',
    severity_hint: 4,
    confidence_hint: 0.8,
    text: 'same payload',
  };

  const first = await service.processRawEvent(payload);
  const second = await service.processRawEvent(payload);

  assert.equal(first.status, 'SUCCESS');
  assert.equal(second.status, 'DUPLICATE');
});
