import { Injectable } from '@nestjs/common';
import { performance } from 'perf_hooks';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import {
  EtaQueryDto,
  LatLngDto,
  RerouteDto,
  RouteOptionsDto,
  RouteResponseWeightsDto,
  RouteWeightsDto,
  TrafficQueryDto,
} from './dto/route-options.dto';
import { RouteCacheService } from './route-cache.service';
import { RoadGraphMaterializationService } from './road-graph-materialization.service';

type EdgeRow = QueryResultRow & {
  source_cell_id: string;
  target_cell_id: string;
  city_id: string;
  region_id: string;
  distance_meters: number;
  base_travel_time_sec: number;
  current_speed_kmh: number;
  traffic_density: number;
  disruption_weight: number;
  risk_score: number;
  road_capacity: number;
  lanes: number;
  speed_limit: number;
  road_type: string;
  dominant_hazard: string | null;
  hazard_count: number;
  edge_cost: number;
  source_lat: number;
  source_lng: number;
  target_lat: number;
  target_lng: number;
};

type NodeRow = QueryResultRow & {
  cell_id: string;
  region_id: string;
  city_id: string;
  center_lat: number;
  center_lng: number;
};

type HistoricalEdgeRow = QueryResultRow & {
  avg_speed_kmh: number;
  congestion_frequency: number;
  incident_frequency: number;
};

type GraphNode = {
  cellId: string;
  lat: number;
  lng: number;
};

type GraphEdge = {
  id: string;
  from: string;
  to: string;
  distanceMeters: number;
  baseTravelTimeSec: number;
  currentSpeedKmh: number;
  trafficDensity: number;
  disruptionWeight: number;
  riskScore: number;
  roadCapacity: number;
  lanes: number;
  speedLimit: number;
  roadType: string;
  dominantHazard: string | null;
  hazardCount: number;
  edgeCost: number;
};

type Graph = {
  adjacency: Map<string, GraphEdge[]>;
  nodes: Map<string, GraphNode>;
};

type SearchState = {
  nodeId: string;
  priority: number;
};

type RouteWeights = {
  distance: number;
  travelTime: number;
  risk: number;
  traffic: number;
  disruption: number;
  capacity: number;
};

type RoutePath = {
  nodeIds: string[];
  edges: GraphEdge[];
  totalDistanceMeters: number;
  totalTravelTimeSec: number;
  totalRisk: number;
  totalCost: number;
};

type ShapedRoute = {
  rank: number;
  routeId: string;
  geometry: Array<{ lat: number; lng: number }>;
  distanceKm: number;
  travelTimeMin: number;
  etaMinutes: number;
  travelDelayMin: number;
  riskScore: number;
  riskLevel: string;
  utility: number;
  explanation: string;
  navigationSteps: Array<{
    step: number;
    instruction: string;
    recommendedLane: string | null;
    distanceMeters: number;
  }>;
  laneGuidance: Array<{
    step: number;
    instruction: string;
    recommendedLane: string | null;
    distanceMeters: number;
  }>;
  segments: Array<{
    segmentId: number;
    fromCellId: string;
    toCellId: string;
    riskScore: number;
    riskLevel: string;
    trafficDensity: number;
    disruptionWeight: number;
    dominantHazard: string | null;
    color: string;
  }>;
  metrics: {
    weights: RouteWeights;
    averageSpeedKmh: number;
    disruptionEdges: number;
    hazardEdges: number;
  };
};

class MinHeap<T extends { priority: number }> {
  private readonly data: T[] = [];

  push(value: T) {
    this.data.push(value);
    this.bubbleUp(this.data.length - 1);
  }

  pop(): T | undefined {
    if (this.data.length === 0) {
      return undefined;
    }
    const root = this.data[0];
    const tail = this.data.pop();
    if (this.data.length > 0 && tail) {
      this.data[0] = tail;
      this.bubbleDown(0);
    }
    return root;
  }

  get size() {
    return this.data.length;
  }

  private bubbleUp(index: number) {
    let current = index;
    while (current > 0) {
      const parent = Math.floor((current - 1) / 2);
      if (this.data[parent].priority <= this.data[current].priority) {
        break;
      }
      [this.data[parent], this.data[current]] = [this.data[current], this.data[parent]];
      current = parent;
    }
  }

  private bubbleDown(index: number) {
    let current = index;
    while (true) {
      const left = (current * 2) + 1;
      const right = left + 1;
      let smallest = current;
      if (left < this.data.length && this.data[left].priority < this.data[smallest].priority) {
        smallest = left;
      }
      if (right < this.data.length && this.data[right].priority < this.data[smallest].priority) {
        smallest = right;
      }
      if (smallest === current) {
        break;
      }
      [this.data[current], this.data[smallest]] = [this.data[smallest], this.data[current]];
      current = smallest;
    }
  }
}

@Injectable()
export class RouteOptionsService {
  private readonly defaultWeights: RouteWeights = {
    distance: 1,
    travelTime: 1.25,
    risk: 240,
    traffic: 85,
    disruption: 70,
    capacity: 55,
  };

  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService,
    private readonly routeCache: RouteCacheService,
    private readonly materializer: RoadGraphMaterializationService,
  ) {}

  async getOptions(dto: RouteOptionsDto) {
    const result = await this.computeRoutes(dto);
    return {
      options: result.routes,
      weights: result.weights,
      metadata: result.metadata,
    };
  }

  async route(dto: RouteOptionsDto) {
    const result = await this.computeRoutes(dto);
    return {
      route: result.routes[0] ?? null,
      alternatives: result.routes.slice(1),
      weights: result.weights,
      metadata: result.metadata,
    };
  }

  async reroute(dto: RerouteDto) {
    const result = await this.computeRoutes(dto, dto.current_route ?? []);
    return {
      route: result.routes[0] ?? null,
      alternatives: result.routes.slice(1),
      weights: result.weights,
      metadata: {
        ...result.metadata,
        rerouted: true,
      },
    };
  }

  async eta(dto: EtaQueryDto) {
    const result = await this.computeRoutes(dto);
    const best = result.routes[0] as ShapedRoute | undefined;
    return {
      etaMinutes: best?.travelTimeMin ?? 0,
      distanceKm: best?.distanceKm ?? 0,
      travelDelayMin: best?.travelDelayMin ?? 0,
      routeId: best?.routeId ?? null,
      riskScore: best?.riskScore ?? 0,
      riskLevel: best?.riskLevel ?? 'LOW',
      metadata: result.metadata,
    };
  }

  async traffic(query: TrafficQueryDto) {
    await this.materializer.ensureReady(false);
    const result = await this.db.queryRead<QueryResultRow>(
      `
        SELECT
          (edge.source_cell_id::h3index)::text AS source_cell_id,
          (edge.target_cell_id::h3index)::text AS target_cell_id,
          edge.current_speed_kmh,
          edge.traffic_density,
          edge.disruption_weight,
          edge.risk_score,
          edge.edge_cost,
          src.center_lat AS source_lat,
          src.center_lng AS source_lng,
          dst.center_lat AS target_lat,
          dst.center_lng AS target_lng,
          edge.dominant_hazard
        FROM routing_edge_weights edge
        JOIN road_graph_nodes src ON src.cell_id = edge.source_cell_id
        JOIN road_graph_nodes dst ON dst.cell_id = edge.target_cell_id
        WHERE ($1::text IS NULL OR edge.city_id = $1)
          AND src.center_lat BETWEEN $2 AND $3
          AND src.center_lng BETWEEN $4 AND $5
        ORDER BY edge.edge_cost DESC
        LIMIT $6
      `,
      [
        query.city_id ?? null,
        query.minLat,
        query.maxLat,
        query.minLng,
        query.maxLng,
        query.limit ?? 128,
      ],
    );

    return {
      traffic: result.rows.map((row) => ({
        sourceCellId: String(row.source_cell_id),
        targetCellId: String(row.target_cell_id),
        currentSpeedKmh: Number(row.current_speed_kmh ?? 0),
        trafficDensity: Number(row.traffic_density ?? 0),
        disruptionWeight: Number(row.disruption_weight ?? 0),
        riskScore: Number(row.risk_score ?? 0),
        edgeCost: Number(row.edge_cost ?? 0),
        dominantHazard: row.dominant_hazard ? String(row.dominant_hazard) : null,
        geometry: [
          { lat: Number(row.source_lat), lng: Number(row.source_lng) },
          { lat: Number(row.target_lat), lng: Number(row.target_lng) },
        ],
      })),
    };
  }

  private async computeRoutes(dto: RouteOptionsDto, currentRoute: LatLngDto[] = []) {
    const started = performance.now();
    await this.materializer.ensureReady(false);

    const weights = this.resolveWeights(dto.weights);
    const strategy = dto.strategy ?? 'ASTAR';
    const alternatives = dto.alternatives ?? 3;
    const cacheKey = this.routeCache.buildKey('route', {
      origin: dto.origin,
      destination: dto.destination,
      cityId: dto.city_id ?? null,
      strategy,
      alternatives,
      weights,
      currentRoute,
      timeBucket: this.timeBucket(),
    });
    const cached = await this.routeCache.get<{
      routes: unknown[];
      weights: RouteResponseWeightsDto;
      metadata: Record<string, unknown>;
    }>(cacheKey);
    if (cached) {
      return {
        ...cached,
        metadata: {
          ...cached.metadata,
          cacheHit: true,
        },
      };
    }

    const distanceKm = this.haversineKm(dto.origin, dto.destination);
    const startNode = await this.findNearestNode(dto.origin, dto.city_id);
    const endNode = await this.findNearestNode(dto.destination, dto.city_id);
    if (!startNode || !endNode) {
      throw new Error('routing graph is not materialized for the requested area');
    }

    const currentRouteCells = new Set(
      currentRoute.map((point) => this.spatial.getH3Index(point.lat, point.lng)),
    );
    const graph = await this.loadGraph(dto.origin, dto.destination, dto.city_id);
    const routes = this.computeCandidateRoutes(
      graph,
      startNode,
      endNode,
      strategy,
      alternatives,
      weights,
      currentRouteCells,
    );

    const historicalMap = await this.loadHistoricalProfiles(routes.flatMap((route) => route.edges));
    const shapedRoutes = routes.map((route, index) =>
      this.formatRoute(route, index, graph.nodes, weights, historicalMap, distanceKm),
    );

    const payload = {
      routes: shapedRoutes,
      weights,
      metadata: {
        strategy,
        alternatives: shapedRoutes.length,
        graphNodes: graph.nodes.size,
        graphEdges: Array.from(graph.adjacency.values()).reduce((sum, bucket) => sum + bucket.length, 0),
        latencyMs: Number((performance.now() - started).toFixed(2)),
        cacheHit: false,
      },
    };
    await this.routeCache.set(cacheKey, payload, 60);
    return payload;
  }

  private async findNearestNode(point: LatLngDto, cityId?: string) {
    const originCell = this.spatial.getH3Index(point.lat, point.lng);
    const parent = this.spatial.getCellParent(originCell);
    const ring = this.spatial
      .getCellNeighbors(parent, 1)
      .concat(this.spatial.getCellNeighbors(parent, 2));
    const regionIds = Array.from(new Set(ring.map((cell) => this.spatial.toDbIndex(cell))));

    const result = await this.db.queryRead<NodeRow>(
      `
        SELECT
          (cell_id::h3index)::text AS cell_id,
          region_id::text AS region_id,
          city_id,
          center_lat,
          center_lng
        FROM road_graph_nodes
        WHERE ($1::text IS NULL OR city_id = $1)
          AND region_id = ANY($2::bigint[])
        ORDER BY POWER(center_lat - $3, 2) + POWER(center_lng - $4, 2)
        LIMIT 1
      `,
      [cityId ?? null, regionIds, point.lat, point.lng],
    );

    if (result.rows.length > 0) {
      return {
        cellId: String(result.rows[0].cell_id),
        lat: Number(result.rows[0].center_lat),
        lng: Number(result.rows[0].center_lng),
      };
    }

    const fallback = await this.db.queryRead<NodeRow>(
      `
        SELECT
          (cell_id::h3index)::text AS cell_id,
          region_id::text AS region_id,
          city_id,
          center_lat,
          center_lng
        FROM road_graph_nodes
        WHERE ($1::text IS NULL OR city_id = $1)
        ORDER BY POWER(center_lat - $2, 2) + POWER(center_lng - $3, 2)
        LIMIT 1
      `,
      [cityId ?? null, point.lat, point.lng],
    );

    if (fallback.rows.length === 0) {
      return null;
    }

    return {
      cellId: String(fallback.rows[0].cell_id),
      lat: Number(fallback.rows[0].center_lat),
      lng: Number(fallback.rows[0].center_lng),
    };
  }

  private async loadGraph(origin: LatLngDto, destination: LatLngDto, cityId?: string): Promise<Graph> {
    const distanceKm = this.haversineKm(origin, destination);
    const margin = Math.max(0.05, distanceKm / 80);
    const minLat = Math.min(origin.lat, destination.lat) - margin;
    const maxLat = Math.max(origin.lat, destination.lat) + margin;
    const minLng = Math.min(origin.lng, destination.lng) - margin;
    const maxLng = Math.max(origin.lng, destination.lng) + margin;
    const regionIds = this.spatial.getCoveringRegions(minLat, minLng, maxLat, maxLng);

    const result = await this.db.queryRead<EdgeRow>(
      `
        SELECT
          (edge.source_cell_id::h3index)::text AS source_cell_id,
          (edge.target_cell_id::h3index)::text AS target_cell_id,
          edge.city_id,
          edge.region_id::text AS region_id,
          edge.distance_meters,
          edge.base_travel_time_sec,
          edge.current_speed_kmh,
          edge.traffic_density,
          edge.disruption_weight,
          edge.risk_score,
          edge.road_capacity,
          edge.lanes,
          edge.speed_limit,
          edge.road_type,
          edge.dominant_hazard,
          edge.hazard_count,
          edge.edge_cost,
          src.center_lat AS source_lat,
          src.center_lng AS source_lng,
          dst.center_lat AS target_lat,
          dst.center_lng AS target_lng
        FROM routing_edge_weights edge
        JOIN road_graph_nodes src ON src.cell_id = edge.source_cell_id
        JOIN road_graph_nodes dst ON dst.cell_id = edge.target_cell_id
        WHERE ($1::text IS NULL OR edge.city_id = $1)
          AND edge.region_id = ANY($2::bigint[])
      `,
      [cityId ?? null, regionIds],
    );

    if (result.rows.length === 0) {
      return {
        adjacency: new Map(),
        nodes: new Map(),
      };
    }

    const adjacency = new Map<string, GraphEdge[]>();
    const nodes = new Map<string, GraphNode>();

    for (const row of result.rows) {
      const sourceId = String(row.source_cell_id);
      const targetId = String(row.target_cell_id);
      nodes.set(sourceId, {
        cellId: sourceId,
        lat: Number(row.source_lat),
        lng: Number(row.source_lng),
      });
      nodes.set(targetId, {
        cellId: targetId,
        lat: Number(row.target_lat),
        lng: Number(row.target_lng),
      });

      const edge: GraphEdge = {
        id: `${sourceId}->${targetId}`,
        from: sourceId,
        to: targetId,
        distanceMeters: Number(row.distance_meters),
        baseTravelTimeSec: Number(row.base_travel_time_sec),
        currentSpeedKmh: Number(row.current_speed_kmh),
        trafficDensity: Number(row.traffic_density),
        disruptionWeight: Number(row.disruption_weight),
        riskScore: Number(row.risk_score),
        roadCapacity: Number(row.road_capacity),
        lanes: Number(row.lanes),
        speedLimit: Number(row.speed_limit),
        roadType: String(row.road_type),
        dominantHazard: row.dominant_hazard ? String(row.dominant_hazard) : null,
        hazardCount: Number(row.hazard_count ?? 0),
        edgeCost: Number(row.edge_cost),
      };

      const bucket = adjacency.get(sourceId) ?? [];
      bucket.push(edge);
      adjacency.set(sourceId, bucket);
    }

    return { adjacency, nodes };
  }

  private computeCandidateRoutes(
    graph: Graph,
    start: GraphNode,
    end: GraphNode,
    strategy: 'DIJKSTRA' | 'ASTAR',
    alternatives: number,
    weights: RouteWeights,
    currentRouteCells: Set<string>,
  ) {
    const routes: RoutePath[] = [];
    const penalties = new Map<string, number>();
    const seen = new Set<string>();

    for (let attempt = 0; attempt < alternatives; attempt += 1) {
      const path = this.findPath(graph, start, end, strategy, weights, penalties, currentRouteCells);
      if (!path) {
        break;
      }

      const signature = path.nodeIds.join('>');
      if (seen.has(signature)) {
        break;
      }
      seen.add(signature);
      routes.push(path);

      for (const edge of path.edges) {
        penalties.set(edge.id, (penalties.get(edge.id) ?? 0) + Math.max(600, edge.edgeCost * 4));
      }
    }

    return routes;
  }

  private findPath(
    graph: Graph,
    start: GraphNode,
    end: GraphNode,
    strategy: 'DIJKSTRA' | 'ASTAR',
    weights: RouteWeights,
    penalties: Map<string, number>,
    currentRouteCells: Set<string>,
  ): RoutePath | null {
    const frontier = new MinHeap<SearchState>();
    const distances = new Map<string, number>([[start.cellId, 0]]);
    const previous = new Map<string, { nodeId: string; edge: GraphEdge }>();
    frontier.push({ nodeId: start.cellId, priority: 0 });

    while (frontier.size > 0) {
      const current = frontier.pop();
      if (!current) {
        break;
      }
      if (current.nodeId === end.cellId) {
        break;
      }

      const edges = graph.adjacency.get(current.nodeId) ?? [];
      for (const edge of edges) {
        const nextDistance =
          (distances.get(current.nodeId) ?? Number.POSITIVE_INFINITY) +
          this.computeDynamicCost(edge, weights, penalties.get(edge.id) ?? 0, currentRouteCells);
        if (nextDistance >= (distances.get(edge.to) ?? Number.POSITIVE_INFINITY)) {
          continue;
        }
        distances.set(edge.to, nextDistance);
        previous.set(edge.to, { nodeId: current.nodeId, edge });
        const heuristic = strategy === 'ASTAR'
          ? this.heuristic(graph.nodes.get(edge.to), end, weights)
          : 0;
        frontier.push({
          nodeId: edge.to,
          priority: nextDistance + heuristic,
        });
      }
    }

    if (!previous.has(end.cellId) && start.cellId !== end.cellId) {
      return null;
    }

    const nodeIds: string[] = [end.cellId];
    const edges: GraphEdge[] = [];
    let cursor = end.cellId;
    while (cursor !== start.cellId) {
      const prev = previous.get(cursor);
      if (!prev) {
        return null;
      }
      edges.push(prev.edge);
      nodeIds.push(prev.nodeId);
      cursor = prev.nodeId;
    }

    nodeIds.reverse();
    edges.reverse();
    const totalDistanceMeters = edges.reduce((sum, edge) => sum + edge.distanceMeters, 0);
    const totalTravelTimeSec = edges.reduce((sum, edge) => sum + this.edgeTravelTime(edge), 0);
    const totalRisk = edges.reduce((sum, edge) => sum + edge.riskScore, 0);
    const totalCost = edges.reduce(
      (sum, edge) => sum + this.computeDynamicCost(edge, weights, penalties.get(edge.id) ?? 0, currentRouteCells),
      0,
    );

    return {
      nodeIds,
      edges,
      totalDistanceMeters,
      totalTravelTimeSec,
      totalRisk,
      totalCost,
    };
  }

  private computeDynamicCost(
    edge: GraphEdge,
    weights: RouteWeights,
    penalty: number,
    currentRouteCells: Set<string>,
  ) {
    const capacityPenalty = Math.min(1, 160 / Math.max(edge.roadCapacity, 1));
    const routeReusePenalty =
      currentRouteCells.has(edge.from) || currentRouteCells.has(edge.to)
        ? 75
        : 0;
    return (
      (edge.distanceMeters / 1000) * weights.distance +
      this.edgeTravelTime(edge) * weights.travelTime +
      edge.riskScore * weights.risk +
      edge.trafficDensity * weights.traffic +
      edge.disruptionWeight * weights.disruption +
      capacityPenalty * weights.capacity +
      penalty +
      routeReusePenalty
    );
  }

  private edgeTravelTime(edge: GraphEdge) {
    const speed = Math.max(edge.currentSpeedKmh, 5);
    return edge.distanceMeters / speed * 3.6;
  }

  private heuristic(node: GraphNode | undefined, end: GraphNode, weights: RouteWeights) {
    if (!node) {
      return 0;
    }
    const distanceKm = this.haversineKm(
      { lat: node.lat, lng: node.lng },
      { lat: end.lat, lng: end.lng },
    );
    return (distanceKm * weights.distance) + ((distanceKm / 70) * 3600 * weights.travelTime);
  }

  private async loadHistoricalProfiles(edges: GraphEdge[]) {
    if (edges.length === 0) {
      return new Map<string, HistoricalEdgeRow>();
    }
    const unique = Array.from(new Set(edges.map((edge) => edge.id)));
    const sources = unique.map((entry) => this.parseEdgeId(entry).from);
    const targets = unique.map((entry) => this.parseEdgeId(entry).to);
    const now = new Date();
    const dayOfWeek = now.getUTCDay();
    const hourOfDay = now.getUTCHours();

    const result = await this.db.queryRead<HistoricalEdgeRow & { source_cell_id: string; target_cell_id: string }>(
      `
        SELECT
          (source_cell_id::h3index)::text AS source_cell_id,
          (target_cell_id::h3index)::text AS target_cell_id,
          avg_speed_kmh,
          congestion_frequency,
          incident_frequency
        FROM historical_traffic_edges
        WHERE source_cell_id = ANY($1::bigint[])
          AND target_cell_id = ANY($2::bigint[])
          AND day_of_week = $3
          AND hour_of_day = $4
      `,
      [sources, targets, dayOfWeek, hourOfDay],
    );

    const map = new Map<string, HistoricalEdgeRow>();
    for (const row of result.rows) {
      map.set(`${row.source_cell_id}->${row.target_cell_id}`, row);
    }
    return map;
  }

  private formatRoute(
    path: RoutePath,
    index: number,
    nodes: Map<string, GraphNode>,
    weights: RouteWeights,
    history: Map<string, HistoricalEdgeRow>,
    directDistanceKm: number,
  ): ShapedRoute {
    const geometry = path.nodeIds.map((nodeId) => {
      const node = nodes.get(nodeId);
      return {
        lat: Number(node?.lat ?? 0),
        lng: Number(node?.lng ?? 0),
      };
    });
    const distanceKm = path.totalDistanceMeters / 1000;
    const travelTimeMin = path.totalTravelTimeSec / 60;
    const riskScore = path.edges.length === 0
      ? 0
      : Math.min(0.999999, path.totalRisk / path.edges.length);
    const riskLevel = this.classifyRisk(riskScore);
    const travelDelayMin = Math.max(0, travelTimeMin - ((directDistanceKm / 42) * 60));
    const explanation = this.explainRoute(path);
    const segments = path.edges.map((edge, edgeIndex) => ({
      segmentId: edgeIndex + 1,
      fromCellId: edge.from,
      toCellId: edge.to,
      riskScore: Number(edge.riskScore.toFixed(4)),
      riskLevel: this.classifyRisk(edge.riskScore),
      trafficDensity: Number(edge.trafficDensity.toFixed(4)),
      disruptionWeight: Number(edge.disruptionWeight.toFixed(4)),
      dominantHazard: edge.dominantHazard,
      color: this.segmentColor(edge.riskScore),
    }));

    const navigationSteps = this.buildNavigationSteps(path, nodes);
    const historicalDelayMin = path.edges.reduce((sum, edge) => {
      const profile = history.get(edge.id);
      if (!profile) {
        return sum;
      }
      const avgSpeed = Number(profile.avg_speed_kmh ?? 0);
      if (avgSpeed <= 0) {
        return sum;
      }
      return sum + Math.max(0, ((edge.distanceMeters / avgSpeed) * 0.06) - (this.edgeTravelTime(edge) / 60));
    }, 0);

    return {
      rank: index + 1,
      routeId: `route-${index + 1}`,
      geometry,
      distanceKm: Number(distanceKm.toFixed(2)),
      travelTimeMin: Number(travelTimeMin.toFixed(1)),
      etaMinutes: Number((travelTimeMin + historicalDelayMin).toFixed(1)),
      travelDelayMin: Number(travelDelayMin.toFixed(1)),
      riskScore: Number(riskScore.toFixed(4)),
      riskLevel,
      utility: Number(path.totalCost.toFixed(3)),
      explanation,
      navigationSteps,
      laneGuidance: navigationSteps.filter((step) => step.recommendedLane !== null),
      segments,
      metrics: {
        weights,
        averageSpeedKmh: Number(
          (
            path.edges.reduce((sum, edge) => sum + edge.currentSpeedKmh, 0) /
            Math.max(path.edges.length, 1)
          ).toFixed(1),
        ),
        disruptionEdges: path.edges.filter((edge) => edge.disruptionWeight > 0.2).length,
        hazardEdges: path.edges.filter((edge) => edge.dominantHazard).length,
      },
    };
  }

  private buildNavigationSteps(path: RoutePath, nodes: Map<string, GraphNode>) {
    if (path.nodeIds.length < 2) {
      return [];
    }

    const steps = [];
    for (let i = 1; i < path.nodeIds.length; i += 1) {
      const prev = nodes.get(path.nodeIds[i - 1]);
      const current = nodes.get(path.nodeIds[i]);
      const next = nodes.get(path.nodeIds[i + 1]);
      if (!prev || !current) {
        continue;
      }
      const instruction = this.instructionForStep(prev, current, next);
      const edge = path.edges[i - 1];
      steps.push({
        step: i,
        instruction: instruction.text,
        recommendedLane: this.recommendedLane(edge.lanes, instruction.turn),
        distanceMeters: Number(edge.distanceMeters.toFixed(1)),
      });
    }
    return steps;
  }

  private instructionForStep(previous: GraphNode, current: GraphNode, next?: GraphNode) {
    if (!next) {
      return { text: 'Arrive at destination', turn: 'ARRIVE' as const };
    }

    const bearingIn = this.bearing(previous, current);
    const bearingOut = this.bearing(current, next);
    let delta = bearingOut - bearingIn;
    while (delta > 180) delta -= 360;
    while (delta < -180) delta += 360;

    if (delta > 35) {
      return { text: 'Turn right', turn: 'RIGHT' as const };
    }
    if (delta < -35) {
      return { text: 'Turn left', turn: 'LEFT' as const };
    }
    return { text: 'Continue straight', turn: 'STRAIGHT' as const };
  }

  private recommendedLane(lanes: number, turn: 'LEFT' | 'RIGHT' | 'STRAIGHT' | 'ARRIVE') {
    if (lanes <= 1 || turn === 'ARRIVE') {
      return null;
    }
    if (turn === 'LEFT') {
      return 'leftmost';
    }
    if (turn === 'RIGHT') {
      return 'rightmost';
    }
    return lanes >= 3 ? 'center' : 'keep lane';
  }

  private explainRoute(path: RoutePath) {
    const hazardCounts = new Map<string, number>();
    let congestionEdges = 0;
    for (const edge of path.edges) {
      if (edge.trafficDensity >= 0.55) {
        congestionEdges += 1;
      }
      if (edge.dominantHazard) {
        hazardCounts.set(edge.dominantHazard, (hazardCounts.get(edge.dominantHazard) ?? 0) + 1);
      }
    }

    const dominantHazard = Array.from(hazardCounts.entries()).sort((a, b) => b[1] - a[1])[0]?.[0];
    if (dominantHazard) {
      return `${dominantHazard.toLowerCase().replace(/_/g, ' ')} ahead with elevated corridor risk`;
    }
    if (congestionEdges > 0) {
      return `high congestion zone across ${congestionEdges} route segment${congestionEdges > 1 ? 's' : ''}`;
    }
    return 'lowest-cost corridor using precomputed traffic and risk surfaces';
  }

  private classifyRisk(score: number) {
    if (score >= 0.75) return 'CRITICAL';
    if (score >= 0.5) return 'HIGH';
    if (score >= 0.25) return 'MEDIUM';
    return 'LOW';
  }

  private segmentColor(score: number) {
    if (score >= 0.75) return '#6e0d0d';
    if (score >= 0.5) return '#d7301f';
    if (score >= 0.25) return '#f4b400';
    return '#2e7d32';
  }

  private resolveWeights(partial?: RouteWeightsDto): RouteResponseWeightsDto {
    return {
      distance: partial?.distance ?? this.defaultWeights.distance,
      travelTime: partial?.travel_time ?? this.defaultWeights.travelTime,
      risk: partial?.risk ?? this.defaultWeights.risk,
      traffic: partial?.traffic ?? this.defaultWeights.traffic,
      disruption: partial?.disruption ?? this.defaultWeights.disruption,
      capacity: partial?.capacity ?? this.defaultWeights.capacity,
    };
  }

  private timeBucket() {
    const now = new Date();
    return `${now.getUTCDay()}-${now.getUTCHours()}`;
  }

  private parseEdgeId(edgeId: string) {
    const [from, to] = edgeId.split('->');
    return { from, to };
  }

  private haversineKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
    const R = 6371;
    const dLat = ((b.lat - a.lat) * Math.PI) / 180;
    const dLng = ((b.lng - a.lng) * Math.PI) / 180;
    const aa =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((a.lat * Math.PI) / 180) *
        Math.cos((b.lat * Math.PI) / 180) *
        Math.sin(dLng / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(aa), Math.sqrt(1 - aa));
    return R * c;
  }

  private bearing(a: GraphNode, b: GraphNode) {
    const lat1 = (a.lat * Math.PI) / 180;
    const lat2 = (b.lat * Math.PI) / 180;
    const dLng = ((b.lng - a.lng) * Math.PI) / 180;
    const y = Math.sin(dLng) * Math.cos(lat2);
    const x =
      Math.cos(lat1) * Math.sin(lat2) -
      Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
    return (Math.atan2(y, x) * 180) / Math.PI;
  }
}
