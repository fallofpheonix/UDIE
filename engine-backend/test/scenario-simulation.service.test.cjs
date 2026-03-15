const test = require('node:test');
const assert = require('node:assert/strict');
const { ScenarioSimulationService } = require('../dist/src/modules/simulation/scenario-simulation.service');

function createService() {
  const queries = [];
  const db = {
    async query(sql, params) {
      queries.push({ sql: String(sql), params });
      if (String(sql).includes('INSERT INTO simulation_runs')) {
        return { rows: [{ run_id: 'run-1' }] };
      }
      return { rows: [] };
    },
    async queryRead(sql, params) {
      queries.push({ sql: String(sql), params });
      if (String(sql).includes('FROM simulation_runs')) {
        return {
          rows: [{
            run_id: 'run-1',
            scenario_id: 'scenario-1',
            scenario_type: 'STADIUM_EVENT',
            status: 'COMPLETED',
            created_at: '2026-03-15T10:00:00.000Z',
          }],
        };
      }
      if (String(sql).includes('FROM simulation_run_outputs')) {
        return {
          rows: [
            {
              output_type: 'RISK_SURFACE',
              payload: { riskSurface: { cells: [{ cellId: '8928308280fffff', riskScore: 0.7 }] } },
              created_at: '2026-03-15T10:00:00.000Z',
            },
            {
              output_type: 'HORIZON_OUTPUTS',
              payload: { outputs: [{ horizonMinutes: 15, risk_map: [{ cellId: '8928308280fffff', riskScore: 0.74 }] }] },
              created_at: '2026-03-15T10:00:01.000Z',
            },
          ],
        };
      }
      if (String(sql).includes('FROM city_grid_cells cg')) {
        return {
          rows: [
            {
              cell_id: '8928308280fffff',
              region_id: '617700169958293503',
              center_lat: 28.6139,
              center_lng: 77.209,
              road_capacity: 220,
              traffic_density: 0.7,
              average_speed: 22,
              disruption_weight: 0.3,
              risk_score: 0.35,
              vehicle_count: 140,
              historical_incident_probability: 0.4,
              disruption_proximity: 0.2,
            },
            {
              cell_id: '8928308280bffff',
              region_id: '617700169958293503',
              center_lat: 28.615,
              center_lng: 77.211,
              road_capacity: 260,
              traffic_density: 0.45,
              average_speed: 30,
              disruption_weight: 0.1,
              risk_score: 0.18,
              vehicle_count: 90,
              historical_incident_probability: 0.2,
              disruption_proximity: 0.1,
            },
          ],
        };
      }
      return {
        rows: [
          { cell_id: '8928308280fffff', road_capacity: 220, traffic_density: 0.7 },
          { cell_id: '8928308280bffff', road_capacity: 260, traffic_density: 0.45 },
        ],
      };
    },
  };

  const spatial = {
    getCoveringCells() {
      return ['8928308280fffff', '8928308280bffff'];
    },
    getH3Index() {
      return '8928308280fffff';
    },
    getInfluenceNeighbors() {
      return ['8928308280fffff', '8928308280bffff'];
    },
    getCellCenter(cell) {
      return cell === '8928308280fffff' ? [28.6139, 77.209] : [28.615, 77.211];
    },
    toDbIndex(cell) {
      return cell === '8928308280fffff' ? '1001' : '1002';
    },
  };

  const digitalTwin = {
    async getCurrentStateForCoordinate() {
      return {
        trafficDensity: 0.4,
        averageSpeed: 28,
        vehicleCount: 60,
        disruptionWeight: 0.1,
      };
    },
    async upsertCellState() {
      return {
        cellId: '8928308280fffff',
        regionId: '617700169958293503',
        state: {
          trafficDensity: 0.8,
          averageSpeed: 15,
          disruptionWeight: 0.45,
          vehicleCount: 120,
        },
      };
    },
  };

  const disruptionPropagation = {
    async createDisruption() {
      return { id: 'd-1' };
    },
  };

  return {
    service: new ScenarioSimulationService(db, spatial, digitalTwin, disruptionPropagation),
    queries,
  };
}

test('generates a predicted city risk heatmap from density, disruption, and history', async () => {
  const { service } = createService();
  const result = await service.generateRiskSurface({
    city_id: 'default',
    minLat: 28.5,
    maxLat: 28.7,
    minLng: 77.1,
    maxLng: 77.3,
    horizon_minutes: 0,
  });

  assert.equal(result.cells.length, 2);
  assert.ok(result.cells[0].riskScore > 0);
});

test('injects synthetic events into the twin and scenario log', async () => {
  const { service, queries } = createService();
  const result = await service.injectSyntheticEvent({
    scenario_id: 'scenario-1',
    scenario_type: 'STADIUM_EVENT',
    lat: 28.6139,
    lng: 77.209,
    severity: 4,
    estimated_duration_minutes: 90,
    cluster_size: 1,
    radius_cells: 2,
    attendee_count: 10000,
    affected_roads: ['ring-road'],
  });

  assert.equal(result.scenarioId, 'scenario-1');
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO simulation_events')));
});

test('projects future horizons into congestion, risk, and travel-delay maps', async () => {
  const { service } = createService();
  const result = await service.simulateHorizons({
    city_id: 'default',
    minLat: 28.5,
    maxLat: 28.7,
    minLng: 77.1,
    maxLng: 77.3,
    horizons: [15, 30],
    horizon_minutes: 0,
  });

  assert.equal(result.outputs.length, 2);
  assert.equal(result.outputs[0].congestion_map.length, 2);
  assert.equal(result.outputs[0].risk_map.length, 2);
  assert.equal(result.outputs[0].travel_delay_map.length, 2);
});

test('estimates evacuation clearance time from vehicles and exit capacity', async () => {
  const { service } = createService();
  const result = await service.estimateEvacuation({
    minLat: 28.5,
    maxLat: 28.7,
    minLng: 77.1,
    maxLng: 77.3,
    exit_routes: [{ lat: 28.7, lng: 77.3 }],
    vehicle_density_factor: 1.2,
  });

  assert.ok(result.estimatedClearanceMinutes > 0);
  assert.ok(result.totalExitCapacity > 0);
});

test('runs operator simulation and persists scenario outputs', async () => {
  const { service, queries } = createService();
  const result = await service.runOperatorSimulation({
    scenario_id: 'scenario-1',
    scenario_type: 'STADIUM_EVENT',
    lat: 28.6139,
    lng: 77.209,
    severity: 4,
    estimated_duration_minutes: 90,
    cluster_size: 1,
    radius_cells: 2,
    attendee_count: 10000,
    affected_roads: ['ring-road'],
    bounds: {
      minLat: 28.5,
      maxLat: 28.7,
      minLng: 77.1,
      maxLng: 77.3,
    },
    horizons: [15, 30],
  });

  assert.equal(result.run_id, 'run-1');
  assert.ok(queries.some((entry) => entry.sql.includes('INSERT INTO simulation_run_outputs')));
});

test('returns persisted simulation results and risk predictions', async () => {
  const { service } = createService();
  const results = await service.getSimulationResults({ run_id: 'run-1' });
  const predictions = await service.getRiskPredictions({ run_id: 'run-1' });

  assert.equal(results.run_id, 'run-1');
  assert.equal(results.outputs.length, 2);
  assert.equal(predictions.risk_predictions.length, 1);
});
