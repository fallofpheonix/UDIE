import { Injectable, Logger } from '@nestjs/common';
import * as h3 from 'h3-js';
import { DatabaseService } from '../../database/database.service';
import { RoadEdge, RoadNode } from './road-graph.service';
import { PathResult } from './pathfinding.service';
import { TrafficService } from './traffic.service';

export interface NavigationStep {
  stepIndex: number;
  instruction: string;
  distanceM: number;
  durationS: number;
  recommendedLane?: number;
  laneCount?: number;
  roadName?: string;
}

export interface NavigationResult {
  steps: NavigationStep[];
  routePolyline: Array<[number, number]>;
  totalDistanceM: number;
  totalDurationS: number;
  estimatedArrivalIso: string;
  riskExplanations: string[];
}

export interface EtaResult {
  travelTimeS: number;
  estimatedArrivalIso: string;
  distanceM: number;
  trafficDelayS: number;
}

@Injectable()
export class NavigationService {
  private readonly logger = new Logger(NavigationService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly trafficService: TrafficService,
  ) {}

  /**
   * Generate full navigation result from a computed path (Prompts 13–15, 28–29).
   */
  async buildNavigation(path: PathResult): Promise<NavigationResult> {
    const steps = this.generateTurnByTurn(path.nodes, path.edges);
    const polyline = this.buildPolyline(path.edges);
    const eta = await this.computeEta(path);
    const riskExplanations = await this.explainRouteRisk(path);

    return {
      steps,
      routePolyline: polyline,
      totalDistanceM: path.distanceM,
      totalDurationS: eta.travelTimeS,
      estimatedArrivalIso: eta.estimatedArrivalIso,
      riskExplanations,
    };
  }

  /**
   * Generate turn-by-turn instructions (Prompt 13).
   * Uses bearing between consecutive road segments to determine manoeuvre.
   */
  generateTurnByTurn(nodes: RoadNode[], edges: RoadEdge[]): NavigationStep[] {
    if (nodes.length < 2 || edges.length === 0) {
      return [{
        stepIndex: 0,
        instruction: 'Proceed to destination',
        distanceM: edges[0]?.lengthM ?? 0,
        durationS: edges[0]?.baseTravelTimeS ?? 0,
      }];
    }

    const steps: NavigationStep[] = [];

    for (let i = 0; i < edges.length; i++) {
      const edge = edges[i];
      const fromNode = nodes[i];
      const toNode = nodes[i + 1];
      if (!fromNode || !toNode) continue;

      const instruction = this.buildStepInstruction(i, edges, nodes);

      const laneGuidance = this.getLaneGuidance(edge, i < edges.length - 1 ? edges[i + 1] : null);

      steps.push({
        stepIndex: i,
        instruction,
        distanceM: edge.lengthM,
        durationS: edge.baseTravelTimeS,
        roadName: edge.roadType,
        ...laneGuidance,
      });
    }

    return steps;
  }

  /**
   * Lane guidance for an edge (Prompt 14).
   */
  getLaneGuidance(
    currentEdge: RoadEdge,
    nextEdge: RoadEdge | null,
  ): { recommendedLane?: number; laneCount?: number } {
    if (currentEdge.lanes <= 1) return {};

    if (!nextEdge) {
      return { laneCount: currentEdge.lanes, recommendedLane: 1 };
    }

    // If the next edge is a highway, prefer right lanes (lane 1 = rightmost)
    if (nextEdge.isHighway && !currentEdge.isHighway) {
      return { laneCount: currentEdge.lanes, recommendedLane: 1 };
    }

    // If turning, use appropriate lane
    // Default: middle lane for through traffic
    const middleLane = Math.ceil(currentEdge.lanes / 2);
    return { laneCount: currentEdge.lanes, recommendedLane: middleLane };
  }

  /**
   * Merge edge geometries into a single route polyline (Prompt 15).
   * Simplifies using Douglas-Peucker.
   */
  buildPolyline(edges: RoadEdge[]): Array<[number, number]> {
    const coords: Array<[number, number]> = [];
    for (const edge of edges) {
      for (const coord of edge.geometry) {
        coords.push(coord);
      }
    }

    if (coords.length === 0) return [];
    return this.simplifyPolyline(coords, 0.00001);
  }

  /**
   * Compute ETA incorporating traffic prediction and historical delays (Prompt 28).
   */
  async computeEta(path: PathResult): Promise<EtaResult> {
    const edgeIds = path.edges.map(e => e.id);
    const forecasts = await this.trafficService.getTrafficForecast(edgeIds);
    const forecastMap = new Map(forecasts.map(f => [f.edgeId, f]));

    let travelTimeS = 0;
    let historicalDelayS = 0;

    for (const edge of path.edges) {
      const forecast = forecastMap.get(edge.id);
      if (forecast) {
        // Live-weighted ETA (Prompt 28)
        const liveSpeedKmh = forecast.forecast15m;
        const liveTimeS = liveSpeedKmh > 0 ? (edge.lengthM / 1000) / liveSpeedKmh * 3600 : edge.baseTravelTimeS;
        travelTimeS += liveTimeS * 0.6 + edge.baseTravelTimeS * 0.4;
        const baseTimeS = edge.baseTravelTimeS;
        if (liveTimeS > baseTimeS) historicalDelayS += liveTimeS - baseTimeS;
      } else {
        travelTimeS += edge.baseTravelTimeS * edge.disruptionWeight;
      }
    }

    const arrivalTime = new Date(Date.now() + travelTimeS * 1000);

    return {
      travelTimeS: Math.round(travelTimeS),
      estimatedArrivalIso: arrivalTime.toISOString(),
      distanceM: path.distanceM,
      trafficDelayS: Math.round(historicalDelayS),
    };
  }

  /**
   * Explain route risk in human-readable terms (Prompt 29).
   */
  async explainRouteRisk(path: PathResult): Promise<string[]> {
    const explanations: string[] = [];

    if (path.riskScore > 0.7) {
      explanations.push('High risk zone: exercise caution along this route');
    } else if (path.riskScore > 0.4) {
      explanations.push('Moderate risk: some disruptions reported');
    }

    // Check active incidents along route
    const routeH3Cells = new Set<string>();
    for (const node of path.nodes) {
      routeH3Cells.add(h3.latLngToCell(node.lat, node.lng, 9));
    }

    const incidents = await this.trafficService.getActiveIncidents();
    for (const incident of incidents) {
      if (routeH3Cells.has(incident.h3Index)) {
        switch (incident.type) {
          case 'sudden_braking':
            explanations.push('Sudden braking reported ahead');
            break;
          case 'speed_collapse':
            explanations.push('Traffic congestion detected on route');
            break;
          default:
            explanations.push(`Incident reported: ${incident.type}`);
        }
      }
    }

    // Check hazards
    const hazards = await this.trafficService.getActiveHazards();
    for (const hazard of hazards) {
      if (routeH3Cells.has(hazard.h3Index) && hazard.probability > 0.5) {
        switch (hazard.hazardType) {
          case 'construction':
            explanations.push('Construction area ahead');
            break;
          case 'accident_zone':
            explanations.push('Frequent accident zone on this route');
            break;
          case 'weather':
            explanations.push('Weather impact zone detected');
            break;
          default:
            explanations.push(`Road hazard: ${hazard.hazardType}`);
        }
      }
    }

    if (explanations.length === 0) explanations.push('Route appears clear');
    return [...new Set(explanations)];
  }

  private buildStepInstruction(i: number, edges: RoadEdge[], nodes: RoadNode[]): string {
    const edge = edges[i];
    if (i === 0) return `Start on ${edge.roadType} road`;
    if (i === edges.length - 1) return 'Arrive at destination';

    const fromNode = nodes[i];
    const prevNode = nodes[i - 1];
    const toNode = nodes[i + 1];

    if (fromNode && prevNode && toNode) {
      const prevBearing = this.bearing(prevNode.lat, prevNode.lng, fromNode.lat, fromNode.lng);
      const nextBearing = this.bearing(fromNode.lat, fromNode.lng, toNode.lat, toNode.lng);
      return this.turnInstruction(prevBearing, nextBearing, edge);
    }
    return 'Continue straight';
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  private bearing(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const lat1R = (lat1 * Math.PI) / 180;
    const lat2R = (lat2 * Math.PI) / 180;
    const y = Math.sin(dLng) * Math.cos(lat2R);
    const x = Math.cos(lat1R) * Math.sin(lat2R) - Math.sin(lat1R) * Math.cos(lat2R) * Math.cos(dLng);
    return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
  }

  private turnInstruction(prevBearing: number, nextBearing: number, edge: RoadEdge): string {
    let diff = nextBearing - prevBearing;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    if (edge.isHighway && Math.abs(diff) < 30) {
      return `Continue on highway (${edge.roadType})`;
    }
    if (diff < -60) return 'Turn left';
    if (diff > 60) return 'Turn right';
    if (diff < -20) return 'Bear left';
    if (diff > 20) return 'Bear right';
    return 'Continue straight';
  }

  private simplifyPolyline(
    coords: Array<[number, number]>,
    epsilon: number,
  ): Array<[number, number]> {
    if (coords.length < 3) return coords;

    let maxDist = 0;
    let splitIdx = 0;
    const first = coords[0];
    const last = coords[coords.length - 1];

    for (let i = 1; i < coords.length - 1; i++) {
      const d = this.perpendicularDistance(coords[i], first, last);
      if (d > maxDist) { maxDist = d; splitIdx = i; }
    }

    if (maxDist > epsilon) {
      const left = this.simplifyPolyline(coords.slice(0, splitIdx + 1), epsilon);
      const right = this.simplifyPolyline(coords.slice(splitIdx), epsilon);
      return [...left.slice(0, -1), ...right];
    }
    return [first, last];
  }

  private perpendicularDistance(
    p: [number, number],
    a: [number, number],
    b: [number, number],
  ): number {
    const [px, py] = p;
    const [ax, ay] = a;
    const [bx, by] = b;
    const denom = Math.hypot(by - ay, bx - ax);
    if (denom === 0) return Math.hypot(px - ax, py - ay);
    return Math.abs((by - ay) * px - (bx - ax) * py + bx * ay - by * ax) / denom;
  }
}
