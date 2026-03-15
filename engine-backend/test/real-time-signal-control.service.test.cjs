const test = require('node:test');
const assert = require('node:assert/strict');
const { RealTimeSignalControlService } = require('../dist/src/modules/simulation/real-time-signal-control.service');

test('dispatches bounded real-time control commands under the latency target', async () => {
  const queries = [];
  const service = new RealTimeSignalControlService(
    {
      async query(sql, params) {
        queries.push({ sql: String(sql), params });
        return { rows: [] };
      },
    },
    {
      async coordinate() {
        return {
          coordinatedActions: [
            { intersectionId: 'ix-1', action: 'extend_green', exchangedState: {} },
          ],
        };
      },
    },
  );

  const result = await service.dispatch({ intersection_id: 'ix-1', city_id: 'delhi' });
  assert.equal(result.action, 'extend_green');
  assert.equal(result.withinTarget, true);
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO traffic_signal_control_commands')));
});
