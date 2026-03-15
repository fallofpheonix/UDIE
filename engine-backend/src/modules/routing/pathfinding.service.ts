import { Injectable, Logger } from '@nestjs/common';
import { haversineKm } from '../common/geo.util';
import { GraphAdjacency, RoadEdge, RoadNode } from './road-graph.service';

export interface RouteCostWeights {
  timeWeight: number;
  distanceWeight: number;
  riskWeight: number;
}

export interface PathResult {
  nodes: RoadNode[];
  edges: RoadEdge[];
  distanceM: number;
  travelTimeS: number;
  riskScore: number;
  cost: number;
}

const DEFAULT_WEIGHTS: RouteCostWeights = {
  timeWeight: 1.0,
  distanceWeight: 0.5,
  riskWeight: 2.0,
};

/** Minimum binary heap for [cost, nodeId] pairs (O(log n) push/pop). */
class MinHeap {
  private readonly data: Array<[number, number]> = [];

  get size(): number {
    return this.data.length;
  }

  push(item: [number, number]): void {
    this.data.push(item);
    this._bubbleUp(this.data.length - 1);
  }

  pop(): [number, number] | undefined {
    if (this.data.length === 0) return undefined;
    const top = this.data[0];
    const last = this.data.pop()!;
    if (this.data.length > 0) {
      this.data[0] = last;
      this._sinkDown(0);
    }
    return top;
  }

  private _bubbleUp(i: number): void {
    while (i > 0) {
      const parent = (i - 1) >> 1;
      if (this.data[parent][0] <= this.data[i][0]) break;
      [this.data[parent], this.data[i]] = [this.data[i], this.data[parent]];
      i = parent;
    }
  }

  private _sinkDown(i: number): void {
    const n = this.data.length;
    while (true) {
      let smallest = i;
      const left = 2 * i + 1;
      const right = 2 * i + 2;
      if (left < n && this.data[left][0] < this.data[smallest][0]) smallest = left;
      if (right < n && this.data[right][0] < this.data[smallest][0]) smallest = right;
      if (smallest === i) break;
      [this.data[smallest], this.data[i]] = [this.data[i], this.data[smallest]];
      i = smallest;
    }
  }
}

@Injectable()
export class PathfindingService {
  private readonly logger = new Logger(PathfindingService.name);

  /**
   * Compute edge cost for multi-criteria routing (Prompt 8).
   * cost = timeWeight * travel_time
   *      + distanceWeight * (length / capacity)
   *      + riskWeight * risk_score
   *
   * All heavy computation is done on pre-materialised edge weights.
   */
  computeEdgeCost(edge: RoadEdge, weights: RouteCostWeights): number {
    const travelTime = edge.baseTravelTimeS * edge.disruptionWeight;
    const trafficPenalty = this.congestionPenalty(edge);
    const effectiveTime = travelTime * trafficPenalty;

    const capacityFactor = edge.lanes > 0 ? 1 / edge.lanes : 1;
    const distanceCost = (edge.lengthM / 1000) * capacityFactor;

    return (
      weights.timeWeight * effectiveTime +
      weights.distanceWeight * distanceCost * 3600 +
      weights.riskWeight * edge.riskScore * 3600
    );
  }

  /** Congestion penalty: increases edge cost when density is high or speed drops (Prompt 10) */
  private congestionPenalty(edge: RoadEdge): number {
    const densityPenalty = 1 + Math.min(3, edge.vehicleDensity * 2);
    if (edge.currentSpeedKmh !== null && edge.currentSpeedKmh > 0) {
      const speedRatio = edge.currentSpeedKmh / Math.max(edge.speedLimitKmh, 1);
      if (speedRatio < 0.4) return densityPenalty * 2.5;
      if (speedRatio < 0.7) return densityPenalty * 1.5;
    }
    return densityPenalty;
  }

  /**
   * Dijkstra shortest path (Prompt 5).
   * Uses pre-computed effectiveWeight for O(1) edge evaluation.
   */
  dijkstra(
    graph: GraphAdjacency,
    originId: number,
    destinationId: number,
    weights: RouteCostWeights = DEFAULT_WEIGHTS,
  ): PathResult | null {
    const dist = new Map<number, number>();
    const prev = new Map<number, { node: number; edge: RoadEdge } | null>();
    const visited = new Set<number>();

    dist.set(originId, 0);
    prev.set(originId, null);

    const heap = new MinHeap();
    heap.push([0, originId]);

    while (heap.size > 0) {
      const [currentCost, currentNode] = heap.pop()!;

      if (visited.has(currentNode)) continue;
      visited.add(currentNode);

      if (currentNode === destinationId) break;

      const neighbors = graph.adjacencyList.get(currentNode) ?? [];
      for (const edge of neighbors) {
        const next = edge.targetNode;
        if (visited.has(next)) continue;

        const edgeCost = this.computeEdgeCost(edge, weights);
        const newCost = currentCost + edgeCost;

        if (newCost < (dist.get(next) ?? Infinity)) {
          dist.set(next, newCost);
          prev.set(next, { node: currentNode, edge });
          heap.push([newCost, next]);
        }
      }
    }

    return this.reconstructPath(graph, originId, destinationId, dist, prev, weights);
  }

  /**
   * A* pathfinding with straight-line heuristic (Prompt 6).
   * Heuristic: haversine distance to destination * cost per meter.
   */
  aStar(
    graph: GraphAdjacency,
    originId: number,
    destinationId: number,
    weights: RouteCostWeights = DEFAULT_WEIGHTS,
  ): PathResult | null {
    const destNode = graph.nodes.get(destinationId);
    if (!destNode) return null;

    const gScore = new Map<number, number>();
    const fScore = new Map<number, number>();
    const prev = new Map<number, { node: number; edge: RoadEdge } | null>();
    const visited = new Set<number>();

    gScore.set(originId, 0);
    fScore.set(originId, this.heuristic(graph.nodes.get(originId)!, destNode, weights));
    prev.set(originId, null);

    const heap = new MinHeap();
    heap.push([fScore.get(originId)!, originId]);

    while (heap.size > 0) {
      const [, currentNode] = heap.pop()!;

      if (visited.has(currentNode)) continue;
      visited.add(currentNode);

      if (currentNode === destinationId) break;

      const neighbors = graph.adjacencyList.get(currentNode) ?? [];
      for (const edge of neighbors) {
        const next = edge.targetNode;
        if (visited.has(next)) continue;

        const edgeCost = this.computeEdgeCost(edge, weights);
        const tentativeG = (gScore.get(currentNode) ?? Infinity) + edgeCost;

        if (tentativeG < (gScore.get(next) ?? Infinity)) {
          gScore.set(next, tentativeG);
          prev.set(next, { node: currentNode, edge });
          const nextNode = graph.nodes.get(next);
          if (nextNode) {
            const f = tentativeG + this.heuristic(nextNode, destNode, weights);
            fScore.set(next, f);
            heap.push([f, next]);
          }
        }
      }
    }

    return this.reconstructPath(graph, originId, destinationId, gScore, prev, weights);
  }

  /**
   * A* heuristic: straight-line distance converted to approximate cost (Prompt 6).
   */
  private heuristic(from: RoadNode, to: RoadNode, weights: RouteCostWeights): number {
    const distKm = haversineKm(from.lat, from.lng, to.lat, to.lng);
    const estimatedTimeS = (distKm / 50) * 3600; // assume 50 km/h
    return weights.timeWeight * estimatedTimeS;
  }

  /**
   * Multi-criteria routing: returns best route for a weighted combination (Prompt 7).
   * Delegates to A* with the provided weights.
   */
  multiCriteriaRoute(
    graph: GraphAdjacency,
    originId: number,
    destinationId: number,
    weights: RouteCostWeights,
  ): PathResult | null {
    return this.aStar(graph, originId, destinationId, weights);
  }

  /**
   * Yen's k-shortest paths algorithm (Prompt 19).
   * Returns up to k distinct routes from origin to destination.
   */
  kShortestPaths(
    graph: GraphAdjacency,
    originId: number,
    destinationId: number,
    k: number,
    weights: RouteCostWeights = DEFAULT_WEIGHTS,
  ): PathResult[] {
    const results: PathResult[] = [];
    const candidates: PathResult[] = [];
    const seenPaths = new Set<string>();

    const first = this.aStar(graph, originId, destinationId, weights);
    if (!first) return [];

    results.push(first);
    seenPaths.add(this.pathKey(first));

    for (let iter = 0; iter < k - 1 && results.length < k; iter++) {
      const prevPath = results[results.length - 1];

      for (let i = 0; i < prevPath.nodes.length - 1; i++) {
        const spurNode = prevPath.nodes[i];
        const rootPath = prevPath.nodes.slice(0, i + 1);
        const rootEdges = prevPath.edges.slice(0, i);

        // Build modified graph excluding edges used by existing paths at spur
        const blockedEdges = new Set<number>();
        for (const existing of results) {
          if (existing.nodes.length > i && existing.nodes[i].id === spurNode.id) {
            const nextEdge = existing.edges[i];
            if (nextEdge) blockedEdges.add(nextEdge.id);
          }
        }

        // Build modified adjacency excluding blocked edges and root nodes (except spur)
        const rootNodeIds = new Set(rootPath.slice(0, -1).map(n => n.id));
        const modifiedAdj = new Map<number, RoadEdge[]>();
        for (const [nodeId, edges] of graph.adjacencyList.entries()) {
          if (rootNodeIds.has(nodeId) && nodeId !== spurNode.id) continue;
          const filteredEdges = edges.filter(e => !blockedEdges.has(e.id));
          if (filteredEdges.length > 0) modifiedAdj.set(nodeId, filteredEdges);
        }
        const modifiedGraph: GraphAdjacency = { adjacencyList: modifiedAdj, nodes: graph.nodes };

        const spurPath = this.aStar(modifiedGraph, spurNode.id, destinationId, weights);
        if (!spurPath) continue;

        const totalNodes = [
          ...rootPath.slice(0, -1),
          ...spurPath.nodes,
        ];
        const totalEdges = [...rootEdges, ...spurPath.edges];

        const candidate: PathResult = {
          nodes: totalNodes,
          edges: totalEdges,
          distanceM: totalEdges.reduce((s, e) => s + e.lengthM, 0),
          travelTimeS: totalEdges.reduce((s, e) => s + e.baseTravelTimeS * e.disruptionWeight, 0),
          riskScore: totalEdges.length > 0
            ? totalEdges.reduce((s, e) => s + e.riskScore, 0) / totalEdges.length
            : 0,
          cost: rootEdges.reduce((s, e) => s + this.computeEdgeCost(e, weights), 0) + spurPath.cost,
        };

        const key = this.pathKey(candidate);
        if (!seenPaths.has(key)) {
          seenPaths.add(key);
          candidates.push(candidate);
        }
      }

      if (candidates.length === 0) break;
      candidates.sort((a, b) => a.cost - b.cost);
      results.push(candidates.shift()!);
    }

    return results.slice(0, k);
  }

  /** Resolve weight preset from mode string */
  resolveWeights(
    mode?: string,
    timeWeight?: number,
    distanceWeight?: number,
    riskWeight?: number,
    defaults: RouteCostWeights = DEFAULT_WEIGHTS,
  ): RouteCostWeights {
    if (timeWeight !== undefined || distanceWeight !== undefined || riskWeight !== undefined) {
      return {
        timeWeight: timeWeight ?? defaults.timeWeight,
        distanceWeight: distanceWeight ?? defaults.distanceWeight,
        riskWeight: riskWeight ?? defaults.riskWeight,
      };
    }
    switch (mode?.toLowerCase()) {
      case 'fastest':   return { timeWeight: 1.0, distanceWeight: 0.1, riskWeight: 0.5 };
      case 'shortest':  return { timeWeight: 0.3, distanceWeight: 1.0, riskWeight: 0.5 };
      case 'safest':    return { timeWeight: 0.5, distanceWeight: 0.2, riskWeight: 2.0 };
      case 'balanced':
      default:          return defaults;
    }
  }

  private reconstructPath(
    graph: GraphAdjacency,
    originId: number,
    destinationId: number,
    dist: Map<number, number>,
    prev: Map<number, { node: number; edge: RoadEdge } | null>,
    _weights: RouteCostWeights,
  ): PathResult | null {
    if (!dist.has(destinationId)) return null;

    const edges: RoadEdge[] = [];
    const nodes: RoadNode[] = [];
    let current: number = destinationId;

    while (current !== originId) {
      const entry = prev.get(current);
      if (!entry) break;
      const node = graph.nodes.get(current);
      if (node) nodes.unshift(node);
      edges.unshift(entry.edge);
      current = entry.node;
    }

    const originNode = graph.nodes.get(originId);
    if (originNode) nodes.unshift(originNode);

    const distanceM = edges.reduce((s, e) => s + e.lengthM, 0);
    const travelTimeS = edges.reduce((s, e) => s + e.baseTravelTimeS * e.disruptionWeight, 0);
    const riskScore = edges.length > 0
      ? edges.reduce((s, e) => s + e.riskScore, 0) / edges.length
      : 0;

    return {
      nodes,
      edges,
      distanceM,
      travelTimeS,
      riskScore,
      cost: dist.get(destinationId) ?? 0,
    };
  }

  private pathKey(path: PathResult): string {
    return path.nodes.map(n => n.id).join(',');
  }
}
