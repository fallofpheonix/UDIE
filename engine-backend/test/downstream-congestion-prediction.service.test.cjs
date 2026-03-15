const test = require('node:test');
const assert = require('node:assert/strict');
const { DownstreamCongestionPredictionService } = require('../dist/src/modules/simulation/downstream-congestion-prediction.service');

test('predicts downstream congestion with a graph-diffusion forecast', async () => {
  const service = new DownstreamCongestionPredictionService({
    async queryRead() {
      return {
        rows: [
          {
            target_intersection_id: 'ix-2',
            queue_length: 12,
            vehicle_count: 30,
            arrival_rate: 6,
            average_speed: 28,
            congestion_index: 0.55,
            capacity: 260,
            length_meters: 400,
            speed_limit: 40,
          },
        ],
      };
    },
  });

  const result = await service.predict({ intersection_id: 'ix-1', city_id: 'delhi', horizon_steps: 3 });
  assert.equal(result.predictions.length, 1);
  assert.equal(result.model, 'graph-diffusion-forecast');
  assert.ok(result.predictions[0].predictedCongestion > 0);
});
