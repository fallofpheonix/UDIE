const test = require('node:test');
const assert = require('node:assert/strict');
const { NationwideDigitalTwinService } = require('../dist/src/modules/simulation/nationwide-digital-twin.service');

test('summarizes national viewport state by res6 region for regional systems', async () => {
  const service = new NationwideDigitalTwinService(
    {
      async query() {
        return { rows: [] };
      },
      async queryRead(sql) {
        if (String(sql).includes('FROM digital_twin_cell_states')) {
          return {
            rows: [{
              region_id: '1',
              traffic_density: 0.5,
              average_speed: 31,
              risk_level: 0.2,
              cell_count: 12,
            }],
          };
        }
        return {
          rows: [{
            region_id: '1',
            region_name: 'north',
            cluster_endpoint: 'http://cluster-a',
            city_id: 'delhi',
          }],
        };
      },
    },
    {
      getCoveringRegions() {
        return ['1'];
      },
    },
  );

  const result = await service.regionalView({ minLat: 20, minLng: 70, maxLat: 30, maxLng: 80 });
  assert.equal(result.shardResolution, 6);
  assert.equal(result.regions.length, 1);
  assert.equal(result.regions[0].clusterEndpoint, 'http://cluster-a');
});
