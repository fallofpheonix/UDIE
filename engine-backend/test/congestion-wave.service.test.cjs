const test = require('node:test');
const assert = require('node:assert/strict');
const { CongestionWaveService } = require('../dist/src/modules/simulation/congestion-wave.service');

function createService() {
  const db = {
    async queryRead(sql) {
      const statement = String(sql);
      if (statement.includes('FROM digital_twin_cell_states')) {
        return {
          rows: [
            {
              cell_id: '8928308280fffff',
              region_id: '617700169958293503',
              road_capacity: 200,
              traffic_density: 0.85,
              average_speed: 18,
              disruption_weight: 0.35,
              risk_score: 0.4,
              vehicle_count: 160,
            },
            {
              cell_id: '8928308280bffff',
              region_id: '617700169958293503',
              road_capacity: 240,
              traffic_density: 0.45,
              average_speed: 32,
              disruption_weight: 0.1,
              risk_score: 0.2,
              vehicle_count: 108,
            },
            {
              cell_id: '89283082807ffff',
              region_id: '617700169958293503',
              road_capacity: 260,
              traffic_density: 0.3,
              average_speed: 38,
              disruption_weight: 0.05,
              risk_score: 0.1,
              vehicle_count: 78,
            },
          ],
        };
      }
      if (statement.includes('FROM city_grid_edges')) {
        return {
          rows: [
            {
              source_cell_id: '8928308280fffff',
              target_cell_id: '8928308280bffff',
              directional_bias: 1,
              transfer_capacity: 40,
            },
            {
              source_cell_id: '8928308280bffff',
              target_cell_id: '89283082807ffff',
              directional_bias: 1,
              transfer_capacity: 30,
            },
          ],
        };
      }
      return { rows: [] };
    },
  };

  const spatial = {
    getH3Index() {
      return '8928308280fffff';
    },
    getInfluenceNeighbors() {
      return ['8928308280fffff', '8928308280bffff', '89283082807ffff'];
    },
    getGridDistance(origin, destination) {
      if (origin === destination) return 0;
      return destination === '8928308280bffff' ? 1 : 2;
    },
    toDbIndex(cell) {
      return cell === '8928308280fffff' ? '1001' : cell === '8928308280bffff' ? '1002' : '1003';
    },
  };

  return new CongestionWaveService(db, spatial);
}

test('simulates downstream congestion wave across connected cells', async () => {
  const service = createService();
  const result = await service.simulate({
    lat: 28.6139,
    lng: 77.209,
    arrivalRate: 0.4,
    horizonSteps: 2,
  });

  assert.equal(result.horizonSteps, 2);
  assert.ok(result.steps[0].cells.some((cell) => cell.cellId === '8928308280bffff'));
  assert.ok(result.waveFrontCells.length >= 1);
});

test('estimates impact radius and delay from severity, density, and topology', async () => {
  const service = createService();
  const result = await service.estimateImpactRadius({
    severity: 4,
    trafficDensity: 0.8,
    lat: 28.6139,
    lng: 77.209,
    affectedRoads: ['ring-road', 'outer-ring'],
    maxRings: 3,
  });

  assert.ok(result.affected_cells.length >= 1);
  assert.ok(result.impact_radius >= 300);
  assert.ok(result.predicted_delay > 0);
});
