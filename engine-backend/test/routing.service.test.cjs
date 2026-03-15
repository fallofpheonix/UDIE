'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { PathfindingService } = require('../dist/src/modules/routing/pathfinding.service');

function makeService() {
  return new PathfindingService();
}

/**
 * Build a simple 4-node graph:
 *
 *   1 --5s--> 2 --5s--> 4
 *   |                   |
 *   +----10s----------->+
 *       (3 is not used here but tests longer path)
 *
 * Nodes: { id, lat, lng, h3Index, h3Partition, isHighway }
 */
function buildTestGraph() {
  const nodes = new Map();
  nodes.set(1, { id: 1, lat: 28.60, lng: 77.20, h3Index: 'a', h3Partition: 'p1', isHighway: false });
  nodes.set(2, { id: 2, lat: 28.61, lng: 77.21, h3Index: 'b', h3Partition: 'p1', isHighway: false });
  nodes.set(3, { id: 3, lat: 28.62, lng: 77.22, h3Index: 'c', h3Partition: 'p1', isHighway: false });
  nodes.set(4, { id: 4, lat: 28.63, lng: 77.23, h3Index: 'd', h3Partition: 'p1', isHighway: false });

  function makeEdge(id, src, tgt, lengthM, speedKmh, isHighway) {
    const baseTravelTimeS = (lengthM / 1000) / Math.max(speedKmh, 5) * 3600;
    return {
      id,
      sourceNode: src,
      targetNode: tgt,
      lengthM,
      lanes: 2,
      speedLimitKmh: speedKmh,
      roadType: 'primary',
      isOneWay: true,
      isHighway: isHighway || false,
      baseTravelTimeS,
      currentSpeedKmh: null,
      vehicleDensity: 0,
      disruptionWeight: 1.0,
      riskScore: 0,
      effectiveWeight: baseTravelTimeS,
      h3Partition: 'p1',
      geometry: [],
    };
  }

  const adjacencyList = new Map();
  adjacencyList.set(1, [makeEdge(10, 1, 2, 500, 50), makeEdge(11, 1, 4, 2000, 50)]);
  adjacencyList.set(2, [makeEdge(12, 2, 4, 500, 50)]);
  adjacencyList.set(3, []);
  adjacencyList.set(4, []);

  return { adjacencyList, nodes };
}

test('PathfindingService: Dijkstra finds shortest path (1->4 via 1->2->4)', () => {
  const svc = makeService();
  const graph = buildTestGraph();
  const result = svc.dijkstra(graph, 1, 4);

  assert.ok(result !== null, 'Expected a path result');
  // 1->2->4 has distance 1000m (500+500), 1->4 direct is 2000m
  assert.equal(result.nodes[0].id, 1);
  assert.equal(result.nodes[result.nodes.length - 1].id, 4);
  assert.ok(result.distanceM < 2000, `Expected route via 1->2->4 (distanceM=${result.distanceM})`);
});

test('PathfindingService: A* finds same path as Dijkstra', () => {
  const svc = makeService();
  const graph = buildTestGraph();
  const dijkstraResult = svc.dijkstra(graph, 1, 4);
  const astarResult = svc.aStar(graph, 1, 4);

  assert.ok(astarResult !== null, 'Expected A* path result');
  assert.equal(
    dijkstraResult.nodes.map(n => n.id).join(','),
    astarResult.nodes.map(n => n.id).join(','),
    'Dijkstra and A* should find the same path',
  );
});

test('PathfindingService: returns null when destination unreachable', () => {
  const svc = makeService();
  const graph = buildTestGraph();
  // Node 5 doesn't exist
  const result = svc.dijkstra(graph, 1, 99);
  assert.equal(result, null, 'Should return null for unreachable destination');
});

test('PathfindingService: kShortestPaths returns at most k paths', () => {
  const svc = makeService();
  const graph = buildTestGraph();
  const paths = svc.kShortestPaths(graph, 1, 4, 3);

  assert.ok(paths.length >= 1, 'Should return at least 1 path');
  assert.ok(paths.length <= 3, 'Should return at most k=3 paths');
  // First path should be shortest
  assert.ok(paths[0].distanceM <= (paths[1]?.distanceM ?? Infinity));
});

test('PathfindingService: computeEdgeCost reflects congestion penalty', () => {
  const svc = makeService();
  const baseEdge = {
    id: 1,
    sourceNode: 1,
    targetNode: 2,
    lengthM: 1000,
    lanes: 2,
    speedLimitKmh: 60,
    roadType: 'primary',
    isOneWay: false,
    isHighway: false,
    baseTravelTimeS: 60,
    currentSpeedKmh: null,
    vehicleDensity: 0,
    disruptionWeight: 1.0,
    riskScore: 0,
    effectiveWeight: 60,
    h3Partition: 'p1',
    geometry: [],
  };

  const weights = { timeWeight: 1.0, distanceWeight: 0.5, riskWeight: 2.0 };
  const baseCost = svc.computeEdgeCost(baseEdge, weights);

  const congestedEdge = { ...baseEdge, vehicleDensity: 0.9, currentSpeedKmh: 10 };
  const congestedCost = svc.computeEdgeCost(congestedEdge, weights);

  assert.ok(congestedCost > baseCost, `Congested cost (${congestedCost}) should exceed base cost (${baseCost})`);
});

test('PathfindingService: resolveWeights returns preset for "fastest" mode', () => {
  const svc = makeService();
  const w = svc.resolveWeights('fastest');
  assert.ok(w.timeWeight > w.distanceWeight, '"fastest" should prioritise time over distance');
});

test('PathfindingService: resolveWeights returns preset for "safest" mode', () => {
  const svc = makeService();
  const w = svc.resolveWeights('safest');
  assert.ok(w.riskWeight > w.timeWeight, '"safest" should prioritise risk over time');
});

test('PathfindingService: multiCriteriaRoute uses custom weights', () => {
  const svc = makeService();
  const graph = buildTestGraph();
  const riskWeights = { timeWeight: 0.1, distanceWeight: 0.1, riskWeight: 5.0 };
  const timeWeights = { timeWeight: 5.0, distanceWeight: 0.1, riskWeight: 0.1 };

  const riskPath = svc.multiCriteriaRoute(graph, 1, 4, riskWeights);
  const timePath = svc.multiCriteriaRoute(graph, 1, 4, timeWeights);

  assert.ok(riskPath !== null, 'Risk-weighted path should exist');
  assert.ok(timePath !== null, 'Time-weighted path should exist');
  // Both should lead to the same destination
  assert.equal(riskPath.nodes[riskPath.nodes.length - 1].id, 4);
  assert.equal(timePath.nodes[timePath.nodes.length - 1].id, 4);
});
