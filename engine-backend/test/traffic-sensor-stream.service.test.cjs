const test = require('node:test');
const assert = require('node:assert/strict');
const { TrafficSensorStreamService } = require('../dist/src/modules/simulation/traffic-sensor-stream.service');

test('normalizes Kafka-style sensor envelopes into twin ingest and stream ledger', async () => {
  const queries = [];
  const service = new TrafficSensorStreamService(
    {
      async query(sql, params) {
        queries.push({ sql: String(sql), params });
        return { rows: [] };
      },
      async queryRead() {
        return { rows: [] };
      },
    },
    {
      async ingestSample() {
        return { cellId: '8928308280fffff', accepted: true };
      },
    },
  );

  const result = await service.ingestKafkaEnvelope({
    city_id: 'delhi',
    source_type: 'GPS_DATA',
    lat: 28.61,
    lng: 77.2,
    vehicle_count: 10,
    average_speed: 32,
    traffic_density: 0.45,
    disruption_weight: 0.1,
  });

  assert.equal(result.accepted, true);
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO traffic_sensor_stream_events')));
});
