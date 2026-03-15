const test = require('node:test');
const assert = require('node:assert/strict');
const { DigitalTwinTickService } = require('../dist/src/modules/simulation/digital-twin-tick.service');

function createService(overrides = {}) {
  const writes = [];
  const storeWrites = [];

  const db = {
    async query(sql, params) {
      const statement = String(sql);
      writes.push({ sql: statement, params });

      if (statement.includes('pg_try_advisory_lock')) {
        return { rows: [{ pg_try_advisory_lock: true }] };
      }
      if (statement.includes('acquire_worker_lock')) {
        return { rows: [{ acquire_worker_lock: true }] };
      }
      if (statement.includes('UPDATE digital_twin_cell_states')) {
        return {
          rows: [{
            cell_id: '8928308280fffff',
            region_id: '617700169958293503',
            traffic_density: 0.92,
            average_speed: 18,
            disruption_weight: 0.74,
            risk_score: 0.61,
            vehicle_count: 49,
            timestamp: '2026-03-15T10:00:00.000Z',
          }],
        };
      }
      if (statement.includes('INSERT INTO digital_twin_state_snapshots')) {
        return { rows: [{ count: 1 }] };
      }
      return { rows: [] };
    },
    ...overrides.db,
  };

  const store = {
    async upsertMany(states) {
      storeWrites.push(...states);
    },
    ...overrides.store,
  };

  return {
    service: new DigitalTwinTickService(db, store),
    writes,
    storeWrites,
  };
}

test('advances the simulation in one bounded SQL update and refreshes cache', async () => {
  const { service, writes, storeWrites } = createService();
  await service.advanceTick();

  assert.ok(writes.some((entry) => entry.sql.includes('UPDATE digital_twin_cell_states')));
  assert.equal(storeWrites.length, 1);
  assert.equal(storeWrites[0].riskScore, 0.61);
});

test('persists periodic state snapshots for historical replay', async () => {
  const { service, writes } = createService();
  await service.snapshotStates();

  assert.ok(writes.some((entry) => entry.sql.includes('INSERT INTO digital_twin_state_snapshots')));
  assert.ok(
    writes.some(
      (entry) =>
        Array.isArray(entry.params) &&
        entry.params.some((param) => param === 'digital_twin_snapshot_worker'),
    ),
  );
});
