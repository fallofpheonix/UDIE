const test = require('node:test');
const assert = require('node:assert/strict');
const { IntersectionStateEstimatorService } = require('../dist/src/modules/simulation/intersection-state-estimator.service');

test('estimates queue, vehicle count, arrival rate, and average speed for an intersection', async () => {
  const service = new IntersectionStateEstimatorService({
    async query() {
      return {
        rows: [
          {
            intersection_id: 'ix-1',
            city_id: 'delhi',
            region_id: '1',
            queue_length: 18,
            vehicle_count: 42,
            arrival_rate: 8.4,
            average_speed: 24,
            congestion_index: 0.72,
          },
        ],
      };
    },
  });

  const result = await service.estimate({ intersection_id: 'ix-1', city_id: 'delhi', lookback_minutes: 5 });
  assert.equal(result.queueLength, 18);
  assert.equal(result.vehicleCount, 42);
  assert.equal(result.arrivalRate, 8.4);
});
