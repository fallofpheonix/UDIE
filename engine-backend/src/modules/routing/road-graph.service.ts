import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import * as h3 from 'h3-js';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';

export interface RoadNode {
  id: number;
  lat: number;
  lng: number;
  h3Index: string;
  h3Partition: string;
  isHighway: boolean;
}

export interface RoadEdge {
  id: number;
  sourceNode: number;
  targetNode: number;
  lengthM: number;
  lanes: number;
  speedLimitKmh: number;
  roadType: string;
  isOneWay: boolean;
  isHighway: boolean;
  baseTravelTimeS: number;
  currentSpeedKmh: number | null;
  vehicleDensity: number;
  disruptionWeight: number;
  riskScore: number;
  effectiveWeight: number;
  h3Partition: string;
  geometry: Array<[number, number]>;
}

export interface GraphAdjacency {
  /** source_node -> array of edges */
  adjacencyList: Map<number, RoadEdge[]>;
  nodes: Map<number, RoadNode>;
  nodesByPartition: Map<string, RoadNode[]>;
  edgeIndex: Map<number, RoadEdge[]>;
}

/** H3 resolution for road network partitioning (aligns with GRAPH_PARTITION_RESOLUTION param) */
const GRAPH_PARTITION_RESOLUTION = 4;

@Injectable()
export class RoadGraphService implements OnModuleInit {
  private readonly logger = new Logger(RoadGraphService.name);

  /** In-memory graph – rebuilt at startup and refreshed periodically */
  private graph: GraphAdjacency = {
    adjacencyList: new Map(),
    nodes: new Map(),
    nodesByPartition: new Map(),
    edgeIndex: new Map(),
  };

  /** Highway-only sub-graph for long-distance routing (Prompt 23) */
  private highwayGraph: GraphAdjacency = {
    adjacencyList: new Map(),
    nodes: new Map(),
    nodesByPartition: new Map(),
    edgeIndex: new Map(),
  };

  private lastGraphLoad = 0;

  constructor(private readonly db: DatabaseService) {}

  async onModuleInit() {
    try {
      await this.rebuildGraph();
    } catch {
      this.logger.warn('[ROAD-GRAPH] Graph not ready at startup — tables may not exist yet');
    }
  }

  /** Return the full in-memory graph */
  getGraph(): GraphAdjacency {
    return this.graph;
  }

  /** Return the highway-only sub-graph */
  getHighwayGraph(): GraphAdjacency {
    return this.highwayGraph;
  }

  /** Rebuild the in-memory adjacency list from the database */
  async rebuildGraph(): Promise<void> {
    const nodesResult = await this.db.queryRead<QueryResultRow>(
      `SELECT id,
              ST_Y(geom::geometry) AS lat,
              ST_X(geom::geometry) AS lng,
              h3_index,
              h3_partition,
              is_highway
       FROM road_nodes`,
    );

    const edgesResult = await this.db.queryRead<QueryResultRow>(
      `SELECT id, source_node, target_node, length_m, lanes,
              speed_limit_kmh, road_type, is_one_way, is_highway,
              base_travel_time_s, current_speed_kmh, vehicle_density,
              disruption_weight, risk_score, effective_weight,
              h3_partition,
              ST_AsGeoJSON(geom::geometry)::json AS geom_json
       FROM road_edges`,
    );

    const nodes = new Map<number, RoadNode>();
    for (const row of nodesResult.rows) {
      nodes.set(Number(row.id), {
        id: Number(row.id),
        lat: Number(row.lat),
        lng: Number(row.lng),
        h3Index: String(row.h3_index),
        h3Partition: String(row.h3_partition),
        isHighway: Boolean(row.is_highway),
      });
    }

    const adjacencyList = new Map<number, RoadEdge[]>();
    const hwAdjacencyList = new Map<number, RoadEdge[]>();
    const nodesByPartition = new Map<string, RoadNode[]>();
    const highwayNodesByPartition = new Map<string, RoadNode[]>();
    const edgeIndex = new Map<number, RoadEdge[]>();
    const highwayEdgeIndex = new Map<number, RoadEdge[]>();

    for (const node of nodes.values()) {
      if (!nodesByPartition.has(node.h3Partition)) nodesByPartition.set(node.h3Partition, []);
      nodesByPartition.get(node.h3Partition)!.push(node);
      if (node.isHighway) {
        if (!highwayNodesByPartition.has(node.h3Partition)) highwayNodesByPartition.set(node.h3Partition, []);
        highwayNodesByPartition.get(node.h3Partition)!.push(node);
      }
    }

    for (const row of edgesResult.rows) {
      const edge: RoadEdge = {
        id: Number(row.id),
        sourceNode: Number(row.source_node),
        targetNode: Number(row.target_node),
        lengthM: Number(row.length_m),
        lanes: Number(row.lanes),
        speedLimitKmh: Number(row.speed_limit_kmh),
        roadType: String(row.road_type),
        isOneWay: Boolean(row.is_one_way),
        isHighway: Boolean(row.is_highway),
        baseTravelTimeS: Number(row.base_travel_time_s),
        currentSpeedKmh: row.current_speed_kmh !== null ? Number(row.current_speed_kmh) : null,
        vehicleDensity: Number(row.vehicle_density),
        disruptionWeight: Number(row.disruption_weight),
        riskScore: Number(row.risk_score),
        effectiveWeight: Number(row.effective_weight),
        h3Partition: String(row.h3_partition),
        geometry: row.geom_json?.coordinates ?? [],
      };

      if (!adjacencyList.has(edge.sourceNode)) adjacencyList.set(edge.sourceNode, []);
      adjacencyList.get(edge.sourceNode)!.push(edge);
      if (!edgeIndex.has(edge.id)) edgeIndex.set(edge.id, []);
      edgeIndex.get(edge.id)!.push(edge);

      if (!edge.isOneWay) {
        if (!adjacencyList.has(edge.targetNode)) adjacencyList.set(edge.targetNode, []);
        const reverseEdge = { ...edge, sourceNode: edge.targetNode, targetNode: edge.sourceNode };
        adjacencyList.get(edge.targetNode)!.push(reverseEdge);
        edgeIndex.get(edge.id)!.push(reverseEdge);
      }

      if (edge.isHighway) {
        if (!hwAdjacencyList.has(edge.sourceNode)) hwAdjacencyList.set(edge.sourceNode, []);
        hwAdjacencyList.get(edge.sourceNode)!.push(edge);
        if (!highwayEdgeIndex.has(edge.id)) highwayEdgeIndex.set(edge.id, []);
        highwayEdgeIndex.get(edge.id)!.push(edge);
        if (!edge.isOneWay) {
          if (!hwAdjacencyList.has(edge.targetNode)) hwAdjacencyList.set(edge.targetNode, []);
          const reverseEdge = { ...edge, sourceNode: edge.targetNode, targetNode: edge.sourceNode };
          hwAdjacencyList.get(edge.targetNode)!.push(reverseEdge);
          highwayEdgeIndex.get(edge.id)!.push(reverseEdge);
        }
      }
    }

    this.graph = { adjacencyList, nodes, nodesByPartition, edgeIndex };
    this.highwayGraph = {
      adjacencyList: hwAdjacencyList,
      nodes,
      nodesByPartition: highwayNodesByPartition,
      edgeIndex: highwayEdgeIndex,
    };
    this.lastGraphLoad = Date.now();

    this.logger.log(
      `[ROAD-GRAPH] Loaded nodes=${nodes.size} edges=${edgesResult.rows.length}`,
    );

    await this.rebuildPartitions(nodes, edgesResult.rows);
  }

  /** Return the road node nearest to a geographic coordinate */
  findNearestNode(lat: number, lng: number, graph?: GraphAdjacency): RoadNode | null {
    const g = graph ?? this.graph;
    if (g.nodes.size === 0) return null;
    const partition = h3.latLngToCell(lat, lng, GRAPH_PARTITION_RESOLUTION);
    const candidates = this.collectNearestNodeCandidates(g, partition);

    let nearest: RoadNode | null = null;
    let minDistSq = Infinity;

    for (const node of candidates) {
      const dLat = node.lat - lat;
      const dLng = node.lng - lng;
      const distSq = dLat * dLat + dLng * dLng;
      if (distSq < minDistSq) {
        minDistSq = distSq;
        nearest = node;
      }
    }
    return nearest;
  }

  /** Update edge weights in-memory after background traffic refresh */
  updateEdgeWeight(edgeId: number, effectiveWeight: number, vehicleDensity: number, currentSpeedKmh: number | null): void {
    const graphEdges = this.graph.edgeIndex.get(edgeId) ?? [];
    for (const edge of graphEdges) {
      edge.effectiveWeight = effectiveWeight;
      edge.vehicleDensity = vehicleDensity;
      edge.currentSpeedKmh = currentSpeedKmh;
    }
    const highwayEdges = this.highwayGraph.edgeIndex.get(edgeId) ?? [];
    for (const edge of highwayEdges) {
      edge.effectiveWeight = effectiveWeight;
      edge.vehicleDensity = vehicleDensity;
      edge.currentSpeedKmh = currentSpeedKmh;
    }
  }

  /**
   * Process an OSM XML/JSON extract and upsert nodes + edges.
   * Production deployment would stream from a full OSM PBF/XML download.
   * This method accepts pre-parsed OSM road data.
   */
  async ingestOsmData(osmNodes: Array<{
    id: number;
    lat: number;
    lng: number;
    osmId?: number;
  }>, osmEdges: Array<{
    id: number;
    osmId?: number;
    sourceNode: number;
    targetNode: number;
    lengthM: number;
    lanes: number;
    speedLimitKmh: number;
    roadType: string;
    isOneWay: boolean;
    isHighway: boolean;
    coordinates: Array<[number, number]>;
  }>, regionCode = 'default'): Promise<{ nodesLoaded: number; edgesLoaded: number }> {
    const logResult = await this.db.query<QueryResultRow>(
      `INSERT INTO osm_ingestion_log (region_code, nodes_loaded, edges_loaded, status)
       VALUES ($1, 0, 0, 'IN_PROGRESS') RETURNING id`,
      [regionCode],
    );
    const logId = logResult.rows[0]?.id as number;

    try {
      let nodesLoaded = 0;
      let edgesLoaded = 0;
      const partitionResolution = GRAPH_PARTITION_RESOLUTION;

      await this.db.withTransaction(async (client) => {
        for (const node of osmNodes) {
          const h3Index = h3.latLngToCell(node.lat, node.lng, 9);
          const h3Partition = h3.latLngToCell(node.lat, node.lng, partitionResolution);
          await client.query(
            `INSERT INTO road_nodes (id, osm_id, geom, h3_index, h3_partition, is_highway)
             VALUES ($1, $2, ST_SetSRID(ST_MakePoint($4, $3), 4326)::geography, $5, $6, FALSE)
             ON CONFLICT (id) DO UPDATE SET
               geom = EXCLUDED.geom,
               h3_index = EXCLUDED.h3_index,
               h3_partition = EXCLUDED.h3_partition,
               updated_at = now()`,
            [node.id, node.osmId ?? null, node.lat, node.lng, h3Index, h3Partition],
          );
          nodesLoaded++;
        }

        for (const edge of osmEdges) {
          const baseTravelTimeS = (edge.lengthM / 1000) / Math.max(edge.speedLimitKmh, 5) * 3600;
          const midIdx = Math.floor(edge.coordinates.length / 2);
          const [midLng, midLat] = edge.coordinates[midIdx] ?? edge.coordinates[0] ?? [0, 0];
          const h3Partition = h3.latLngToCell(midLat, midLng, partitionResolution);
          const geojson = JSON.stringify({ type: 'LineString', coordinates: edge.coordinates });

          await client.query(
            `INSERT INTO road_edges
               (id, osm_id, source_node, target_node, length_m, lanes, speed_limit_kmh,
                road_type, is_one_way, is_highway, geom, base_travel_time_s,
                effective_weight, h3_partition)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
                     ST_GeomFromGeoJSON($11)::geography, $12, $12, $13)
             ON CONFLICT (id) DO UPDATE SET
               length_m = EXCLUDED.length_m,
               lanes = EXCLUDED.lanes,
               speed_limit_kmh = EXCLUDED.speed_limit_kmh,
               road_type = EXCLUDED.road_type,
               is_one_way = EXCLUDED.is_one_way,
               is_highway = EXCLUDED.is_highway,
               geom = EXCLUDED.geom,
               base_travel_time_s = EXCLUDED.base_travel_time_s,
               effective_weight = EXCLUDED.effective_weight,
               h3_partition = EXCLUDED.h3_partition,
               updated_at = now()`,
            [
              edge.id, edge.osmId ?? null, edge.sourceNode, edge.targetNode,
              edge.lengthM, edge.lanes, edge.speedLimitKmh, edge.roadType,
              edge.isOneWay, edge.isHighway, geojson, baseTravelTimeS, h3Partition,
            ],
          );
          edgesLoaded++;
        }
      });

      await this.db.query(
        `UPDATE osm_ingestion_log
         SET nodes_loaded = $1, edges_loaded = $2, status = 'COMPLETED', completed_at = now()
         WHERE id = $3`,
        [nodesLoaded, edgesLoaded, logId],
      );

      this.logger.log(`[OSM] ingested region=${regionCode} nodes=${nodesLoaded} edges=${edgesLoaded}`);
      await this.rebuildGraph();
      return { nodesLoaded, edgesLoaded };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      await this.db.query(
        `UPDATE osm_ingestion_log
         SET status = 'FAILED', completed_at = now(), error_message = $1 WHERE id = $2`,
        [message, logId],
      );
      throw err;
    }
  }

  /** Rebuild H3 partition metadata after graph load */
  private async rebuildPartitions(
    nodes: Map<number, RoadNode>,
    edgeRows: QueryResultRow[],
  ): Promise<void> {
    const partitionNodes = new Map<string, number>();
    const partitionEdges = new Map<string, number>();

    for (const node of nodes.values()) {
      partitionNodes.set(node.h3Partition, (partitionNodes.get(node.h3Partition) ?? 0) + 1);
    }
    for (const row of edgeRows) {
      const p = String(row.h3_partition);
      partitionEdges.set(p, (partitionEdges.get(p) ?? 0) + 1);
    }

    const allPartitions = new Set([...partitionNodes.keys(), ...partitionEdges.keys()]);
    for (const p of allPartitions) {
      await this.db.query(
        `INSERT INTO road_partitions (h3_index, h3_resolution, node_count, edge_count, updated_at)
         VALUES ($1, $2, $3, $4, now())
         ON CONFLICT (h3_index) DO UPDATE SET
           node_count = EXCLUDED.node_count,
           edge_count = EXCLUDED.edge_count,
           updated_at = EXCLUDED.updated_at`,
        [p, GRAPH_PARTITION_RESOLUTION, partitionNodes.get(p) ?? 0, partitionEdges.get(p) ?? 0],
      );
    }
  }

  get graphLoadedAt(): number {
    return this.lastGraphLoad;
  }

  private collectNearestNodeCandidates(graph: GraphAdjacency, partition: string): RoadNode[] {
    const local = graph.nodesByPartition.get(partition);
    if (local && local.length > 0) {
      return local;
    }

    const nearby = new Map<number, RoadNode>();
    for (const candidatePartition of h3.gridDisk(partition, 2)) {
      const nodes = graph.nodesByPartition.get(candidatePartition);
      if (!nodes) continue;
      for (const node of nodes) {
        nearby.set(node.id, node);
      }
    }
    if (nearby.size > 0) {
      return [...nearby.values()];
    }

    return [...graph.nodes.values()];
  }
}
