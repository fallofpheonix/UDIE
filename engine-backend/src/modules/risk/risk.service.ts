import { Injectable, Logger } from '@nestjs/common';
import * as h3 from 'h3-js';
import { RouteRiskDto } from './dto/route-risk.dto';
import { RiskGridService } from './risk-grid.service';
import { SpatialService } from '../common/spatial.service';
import { resolveRouteRegion } from '../common/region-resolver.util';
import { ObservabilityService } from '../common/observability.service';

@Injectable()
export class RiskService {
  private readonly logger = new Logger(RiskService.name);
  private readonly K_NORMALIZATION = 20.0; // Spec v2 Constant
  private readonly MAX_VERTICES = 1000;

  constructor(
    private readonly riskGrid: RiskGridService,
    private readonly spatial: SpatialService,
    private readonly observability: ObservabilityService,
  ) { }

  /**
   * Calculates route risk with <1ms latency using the In-Memory Grid.
   * Implements:
   * 1. H3 Polyline-based route coverage (fixes boundary jitter).
   * 2. Length-normalized risk density (fixes route-length bias).
   * 3. Rational normalization (preserves ranking resolution).
   */
  async calculateRouteRisk(dto: RouteRiskDto) {
    const startTime = performance.now();
    const simplifiedCoordinates = this.simplifyRoute(dto.coordinates);
    const regionId = resolveRouteRegion(simplifiedCoordinates);

    // 1. Convert route to H3 Res 9 polyline coverage
    const routeCells = this.getRouteCells(simplifiedCoordinates);
    if (routeCells.length === 0) {
      const elapsedSec = (performance.now() - startTime) / 1000;
      this.observability.observeRiskEvalLatency(elapsedSec);
      return {
        riskScore: 0,
        riskDensity: 0,
        routeLengthKm: 0,
        latencyMs: parseFloat((performance.now() - startTime).toFixed(2))
      };
    }

    // 2. Expand coverage to include influence boundary (k=3)
    const influenceSet = new Set<string>();
    for (const cell of routeCells) {
      influenceSet.add(cell);
      const neighbors = this.spatial.getInfluenceNeighbors(cell, 3);
      for (const neighbor of neighbors) {
        influenceSet.add(neighbor);
      }
    }

    // 3. Calculate raw integrated risk in single pass
    let rawRisk = 0;
    const pathDistance = this.calculatePathDistance(simplifiedCoordinates);

    for (const cell of influenceSet) {
      const weight = this.riskGrid.getWeight(cell);
      if (weight <= 0) continue;

      // Determine if it's a direct hit or influence
      const isDirect = routeCells.includes(cell);
      if (isDirect) {
        rawRisk += weight;
      } else {
        // Calculate influence weight based on distance to nearest route cell
        // For performance, we treat influence as a simplified average or nearest-neighbor
        const nearestRouteCell = this.findNearestRouteCell(cell, routeCells);
        const dist = this.spatial.getGridDistance(cell, nearestRouteCell);
        rawRisk += weight * this.spatial.getInfluenceWeight(dist);
      }
    }

    // 3. Length Normalization (Risk Density)
    const riskDensity = pathDistance > 0 ? rawRisk / pathDistance : rawRisk;

    // 4. Exponential Saturation Normalization (Spec v2)
    // Rnorm = 1 - exp(-R density / k)
    const normalizedScore = 1 - Math.exp(-riskDensity / this.K_NORMALIZATION);

    const latencyMs = performance.now() - startTime;
    this.observability.observeRiskEvalLatency(latencyMs / 1000);
    this.logger.debug(`[RISK] region=${regionId} risk=${normalizedScore.toFixed(4)} latency_ms=${latencyMs.toFixed(2)}`);

    return {
      riskScore: parseFloat(normalizedScore.toFixed(4)),
      riskDensity: parseFloat(riskDensity.toFixed(4)),
      routeLengthKm: parseFloat(pathDistance.toFixed(2)),
      cellCount: routeCells.length,
      latencyMs: parseFloat(latencyMs.toFixed(2)),
    };
  }

  private simplifyRoute(coords: { lat: number; lng: number }[]): { lat: number; lng: number }[] {
    if (coords.length <= 2) {
      return coords;
    }

    const epsilon = this.computeEpsilon(coords);
    const simplified = this.douglasPeucker(coords, epsilon);

    if (simplified.length <= this.MAX_VERTICES) {
      return simplified;
    }

    const step = Math.ceil(simplified.length / this.MAX_VERTICES);
    const capped: { lat: number; lng: number }[] = [];
    for (let i = 0; i < simplified.length; i += step) {
      capped.push(simplified[i]);
    }
    const last = simplified[simplified.length - 1];
    if (capped[capped.length - 1] !== last) {
      capped.push(last);
    }
    return capped.slice(0, this.MAX_VERTICES);
  }

  private computeEpsilon(coords: { lat: number; lng: number }[]): number {
    const totalDistanceKm = this.calculatePathDistance(coords);
    // 10m baseline tolerance scaled by route length.
    return Math.max(0.00005, Math.min(0.00025, totalDistanceKm / 500000));
  }

  private douglasPeucker(coords: { lat: number; lng: number }[], epsilon: number): { lat: number; lng: number }[] {
    if (coords.length < 3) {
      return coords;
    }

    let maxDistance = 0;
    let splitIndex = 0;
    const first = coords[0];
    const last = coords[coords.length - 1];

    for (let i = 1; i < coords.length - 1; i += 1) {
      const distance = this.perpendicularDistance(coords[i], first, last);
      if (distance > maxDistance) {
        maxDistance = distance;
        splitIndex = i;
      }
    }

    if (maxDistance > epsilon) {
      const left = this.douglasPeucker(coords.slice(0, splitIndex + 1), epsilon);
      const right = this.douglasPeucker(coords.slice(splitIndex), epsilon);
      return left.slice(0, left.length - 1).concat(right);
    }

    return [first, last];
  }

  private perpendicularDistance(
    point: { lat: number; lng: number },
    lineStart: { lat: number; lng: number },
    lineEnd: { lat: number; lng: number },
  ): number {
    const x0 = point.lng;
    const y0 = point.lat;
    const x1 = lineStart.lng;
    const y1 = lineStart.lat;
    const x2 = lineEnd.lng;
    const y2 = lineEnd.lat;

    const denominator = Math.hypot(y2 - y1, x2 - x1);
    if (denominator === 0) {
      return Math.hypot(x0 - x1, y0 - y1);
    }
    return Math.abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1) / denominator;
  }

  /**
   * Uses H3 Polyline for stable cell coverage.
   */
  private getRouteCells(coords: { lat: number, lng: number }[]): string[] {
    try {
      const line = coords.map(c => [c.lat, c.lng]);
      // Use h3.gridPathCells for polyline coverage at resolution 9
      // Note: h3.gridPathCells expects [lat, lng] pairs
      const indices = new Set<string>();
      for (let i = 0; i < line.length - 1; i++) {
        const path = h3.gridPathCells(
          h3.latLngToCell(line[i][0], line[i][1], 9),
          h3.latLngToCell(line[i + 1][0], line[i + 1][1], 9)
        );
        path.forEach(cell => indices.add(cell));
      }
      return Array.from(indices);
    } catch (error) {
      // Fallback to point sampling if path fails
      const indices = new Set<string>();
      coords.forEach(c => indices.add(h3.latLngToCell(c.lat, c.lng, 9)));
      return Array.from(indices);
    }
  }

  /**
   * Basic Haversine path distance calculation.
   */
  private calculatePathDistance(coords: { lat: number, lng: number }[]): number {
    let dist = 0;
    for (let i = 0; i < coords.length - 1; i++) {
      dist += this.haversine(coords[i], coords[i + 1]);
    }
    return dist;
  }

  private findNearestRouteCell(cell: string, routeCells: string[]): string {
    let minDistance = Infinity;
    let nearest = routeCells[0];

    for (const routeCell of routeCells) {
      const dist = this.spatial.getGridDistance(cell, routeCell);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = routeCell;
      }
      if (minDistance === 0) break;
    }
    return nearest;
  }

  private haversine(c1: { lat: number, lng: number }, c2: { lat: number, lng: number }): number {
    const R = 6371; // km
    const dLat = (c2.lat - c1.lat) * Math.PI / 180;
    const dLng = (c2.lng - c1.lng) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(c1.lat * Math.PI / 180) * Math.cos(c2.lat * Math.PI / 180) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }
}
