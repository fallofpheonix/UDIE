const test = require('node:test');
const assert = require('node:assert/strict');
const { FailSafeTrafficControlService } = require('../dist/src/modules/simulation/fail-safe-traffic-control.service');

test('falls back to predefined schedule and manual mode when AI control fails', async () => {
  const queries = [];
  const service = new FailSafeTrafficControlService(
    {
      async query(sql, params) {
        queries.push({ sql: String(sql), params });
        if (String(sql).includes('FROM system_state')) {
          return { rows: [{ key: 'digital_twin_tick_worker', updated_at: '2020-01-01T00:00:00.000Z' }] };
        }
        return { rows: [] };
      },
      async queryRead(sql, params) {
        queries.push({ sql: String(sql), params });
        return {
          rows: [{
            schedule_name: 'fallback_cycle',
            action: 'hold_phase',
            phase_duration_seconds: 45,
            min_phase_seconds: 20,
            max_phase_seconds: 60,
            manual_override_enabled: true,
          }],
        };
      },
    },
    {
      async dispatch() {
        throw new Error('ai_unavailable');
      },
    },
  );

  const result = await service.dispatch({ intersection_id: 'ix-1', city_id: 'delhi' });
  assert.equal(result.failSafe, true);
  assert.equal(result.mode, 'MANUAL_CONTROL');
  assert.equal(result.action, 'hold_phase');
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO traffic_signal_control_modes')));
});
