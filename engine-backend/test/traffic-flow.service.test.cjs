const test = require('node:test');
const assert = require('node:assert/strict');
const { TrafficFlowService } = require('../dist/src/modules/simulation/traffic-flow.service');

function createService(overrides = {}) {
  const queries = [];
  const db = {
    async query(sql, params) {
      queries.push({ sql: String(sql), params });
      return { rows: [] };
    },
    async queryRead(sql, params) {
      queries.push({ sql: String(sql), params });
      return {
        rows: [{
          alert_type: 'SUDDEN_TRAFFIC_CHANGE',
          severity: 4,
          details: { speedDrop: 20 },
          detected_at: '2026-03-15T10:00:00.000Z',
        }],
      };
    },
    ...overrides.db,
  };

  const digitalTwin = {
    async getCurrentStateForCoordinate() {
      return {
        trafficDensity: 0.3,
        averageSpeed: 42,
        vehicleCount: 20,
        disruptionWeight: 0.1,
      };
    },
    async upsertCellState() {
      return {
        cellId: '8928308280fffff',
        regionId: '617700169958293503',
        state: {
          trafficDensity: 0.7,
          averageSpeed: 18,
          vehicleCount: 68,
          disruptionWeight: 0.45,
        },
      };
    },
    ...overrides.digitalTwin,
  };

  return {
    service: new TrafficFlowService(db, digitalTwin),
    queries,
  };
}

test('ingests traffic samples and emits sudden-change alerts on large deltas', async () => {
  const { service, queries } = createService();
  const result = await service.ingestSample({
    city_id: 'delhi',
    lat: 28.6139,
    lng: 77.209,
    traffic_density: 0.7,
    average_speed: 18,
    vehicle_count: 68,
    disruption_weight: 0.45,
  });

  assert.equal(result.changed, true);
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO digital_twin_traffic_samples')));
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO digital_twin_state_alerts')));
});

test('lists cell alerts in descending order', async () => {
  const { service } = createService();
  const result = await service.listAlerts('8928308280fffff', 10);
  assert.equal(result.alerts.length, 1);
  assert.equal(result.alerts[0].alertType, 'SUDDEN_TRAFFIC_CHANGE');
});
