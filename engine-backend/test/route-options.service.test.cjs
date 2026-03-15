const test = require('node:test');
const assert = require('node:assert/strict');
const { RouteOptionsService } = require('../dist/src/modules/route-options/route-options.service');

function createService() {
  const queryRead = async (text, params = []) => {
    if (text.includes('FROM road_graph_nodes') && text.includes('LIMIT 1')) {
      const lat = Number(params[params.length - 2]);
      if (lat < 28.615) {
        return {
          rows: [{
            cell_id: '8928308280fffff',
            region_id: '86283082fffffff',
            city_id: 'delhi',
            center_lat: 28.61,
            center_lng: 77.20,
          }],
        };
      }
      return {
        rows: [{
          cell_id: '8928308281fffff',
          region_id: '86283082fffffff',
          city_id: 'delhi',
          center_lat: 28.62,
          center_lng: 77.21,
        }],
      };
    }

    if (text.includes('FROM routing_edge_weights')) {
      return {
        rows: [
          {
            source_cell_id: '8928308280fffff',
            target_cell_id: '8928308282fffff',
            city_id: 'delhi',
            region_id: '86283082fffffff',
            distance_meters: 600,
            base_travel_time_sec: 72,
            current_speed_kmh: 30,
            traffic_density: 0.2,
            disruption_weight: 0.1,
            risk_score: 0.15,
            road_capacity: 240,
            lanes: 2,
            speed_limit: 40,
            road_type: 'ARTERIAL',
            dominant_hazard: null,
            hazard_count: 0,
            edge_cost: 96,
            source_lat: 28.61,
            source_lng: 77.20,
            target_lat: 28.615,
            target_lng: 77.205,
          },
          {
            source_cell_id: '8928308282fffff',
            target_cell_id: '8928308281fffff',
            city_id: 'delhi',
            region_id: '86283082fffffff',
            distance_meters: 700,
            base_travel_time_sec: 84,
            current_speed_kmh: 30,
            traffic_density: 0.25,
            disruption_weight: 0.1,
            risk_score: 0.2,
            road_capacity: 220,
            lanes: 2,
            speed_limit: 40,
            road_type: 'ARTERIAL',
            dominant_hazard: 'ACCIDENT',
            hazard_count: 2,
            edge_cost: 108,
            source_lat: 28.615,
            source_lng: 77.205,
            target_lat: 28.62,
            target_lng: 77.21,
          },
          {
            source_cell_id: '8928308280fffff',
            target_cell_id: '8928308283fffff',
            city_id: 'delhi',
            region_id: '86283082fffffff',
            distance_meters: 650,
            base_travel_time_sec: 78,
            current_speed_kmh: 24,
            traffic_density: 0.5,
            disruption_weight: 0.3,
            risk_score: 0.6,
            road_capacity: 180,
            lanes: 1,
            speed_limit: 32,
            road_type: 'LOCAL',
            dominant_hazard: 'CONSTRUCTION',
            hazard_count: 3,
            edge_cost: 180,
            source_lat: 28.61,
            source_lng: 77.20,
            target_lat: 28.614,
            target_lng: 77.206,
          },
          {
            source_cell_id: '8928308283fffff',
            target_cell_id: '8928308281fffff',
            city_id: 'delhi',
            region_id: '86283082fffffff',
            distance_meters: 700,
            base_travel_time_sec: 90,
            current_speed_kmh: 22,
            traffic_density: 0.55,
            disruption_weight: 0.3,
            risk_score: 0.65,
            road_capacity: 180,
            lanes: 1,
            speed_limit: 32,
            road_type: 'LOCAL',
            dominant_hazard: 'CONSTRUCTION',
            hazard_count: 3,
            edge_cost: 210,
            source_lat: 28.614,
            source_lng: 77.206,
            target_lat: 28.62,
            target_lng: 77.21,
          },
        ],
      };
    }

    if (text.includes('FROM historical_traffic_edges')) {
      return {
        rows: [{
          source_cell_id: '8928308280fffff',
          target_cell_id: '8928308282fffff',
          avg_speed_kmh: 28,
          congestion_frequency: 0.2,
          incident_frequency: 0.1,
        }],
      };
    }

    throw new Error(`Unexpected query: ${text}`);
  };

  const db = {
    queryRead,
  };
  const spatial = {
    getH3Index(lat) {
      return lat < 28.615 ? '8928308280fffff' : '8928308281fffff';
    },
    getCellParent() {
      return '86283082fffffff';
    },
    getCellNeighbors(cell) {
      return [cell];
    },
    toDbIndex(value) {
      return value;
    },
    getCoveringRegions() {
      return ['86283082fffffff'];
    },
  };
  const cache = {
    buildKey() {
      return 'route-key';
    },
    async get() {
      return null;
    },
    async set() {},
  };
  const materializer = {
    async ensureReady() {},
  };

  return new RouteOptionsService(db, spatial, cache, materializer);
}

test('route returns the lowest-cost graph path with navigation steps', async () => {
  const service = createService();
  const result = await service.route({
    origin: { lat: 28.61, lng: 77.2 },
    destination: { lat: 28.62, lng: 77.21 },
    city_id: 'delhi',
    strategy: 'ASTAR',
    alternatives: 2,
  });

  assert.equal(result.route.routeId, 'route-1');
  assert.equal(result.route.geometry.length, 3);
  assert.ok(result.route.distanceKm > 1);
  assert.ok(result.route.travelTimeMin > 0);
  assert.ok(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].includes(result.route.riskLevel));
  assert.equal(result.alternatives.length, 1);
  assert.match(result.route.explanation, /accident|construction|congestion|lowest-cost/i);
  assert.ok(result.route.navigationSteps.length >= 2);
});

test('reroute penalizes current route cells and returns an alternative corridor', async () => {
  const service = createService();
  const result = await service.reroute({
    origin: { lat: 28.61, lng: 77.2 },
    destination: { lat: 28.62, lng: 77.21 },
    city_id: 'delhi',
    strategy: 'ASTAR',
    alternatives: 2,
    current_route: [
      { lat: 28.61, lng: 77.2 },
      { lat: 28.62, lng: 77.21 },
    ],
  });

  assert.ok(result.route);
  assert.equal(result.metadata.rerouted, true);
  assert.ok(result.route.utility >= 0);
});
