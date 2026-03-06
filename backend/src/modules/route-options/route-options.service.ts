import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { RiskService } from '../risk/risk.service';
import { RouteOptionsDto } from './dto/route-options.dto';

type ParameterMap = {
  routeUtilityTimeWeight: number;
  routeUtilityRiskWeight: number;
  assumedSpeedKmh: number;
};

@Injectable()
export class RouteOptionsService {
  constructor(
    private readonly riskService: RiskService,
    private readonly db: DatabaseService,
  ) {}

  async getOptions(dto: RouteOptionsDto) {
    const params = await this.getModelParameters();
    const routes = this.buildCandidateRoutes(dto.origin, dto.destination);

    const scored = await Promise.all(
      routes.map(async (route, index) => {
        const risk = await this.riskService.calculateRouteRisk({ coordinates: route.geometry });
        const travelTimeMin = this.estimateTravelTimeMinutes(route.distanceKm, params.assumedSpeedKmh);
        const utility = (travelTimeMin * params.routeUtilityTimeWeight) + (risk.riskScore * params.routeUtilityRiskWeight);

        return {
          rankHint: index + 1,
          routeId: `R${index + 1}`,
          geometry: route.geometry,
          distanceKm: Number(route.distanceKm.toFixed(2)),
          travelTimeMin: Number(travelTimeMin.toFixed(1)),
          riskScore: risk.riskScore,
          utility: Number(utility.toFixed(4)),
        };
      }),
    );

    scored.sort((a, b) => a.utility - b.utility);

    return {
      options: scored.slice(0, 3).map((item, idx) => ({ ...item, rank: idx + 1 })),
      weights: {
        time: params.routeUtilityTimeWeight,
        risk: params.routeUtilityRiskWeight,
      },
    };
  }

  private buildCandidateRoutes(origin: { lat: number; lng: number }, destination: { lat: number; lng: number }) {
    const midLat = (origin.lat + destination.lat) / 2;
    const midLng = (origin.lng + destination.lng) / 2;

    const dLat = destination.lat - origin.lat;
    const dLng = destination.lng - origin.lng;
    const norm = Math.hypot(dLat, dLng) || 1;
    const perpLat = -dLng / norm;
    const perpLng = dLat / norm;
    const offsetScale = 0.02 * Math.hypot(dLat, dLng);

    const straight = [origin, destination];
    const northArc = [
      origin,
      { lat: midLat + perpLat * offsetScale, lng: midLng + perpLng * offsetScale },
      destination,
    ];
    const southArc = [
      origin,
      { lat: midLat - perpLat * offsetScale, lng: midLng - perpLng * offsetScale },
      destination,
    ];

    return [straight, northArc, southArc].map((geometry) => ({
      geometry,
      distanceKm: this.computeDistanceKm(geometry),
    }));
  }

  private computeDistanceKm(points: Array<{ lat: number; lng: number }>): number {
    let total = 0;
    for (let i = 0; i < points.length - 1; i += 1) {
      total += this.haversineKm(points[i], points[i + 1]);
    }
    return total;
  }

  private haversineKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
    const R = 6371;
    const dLat = ((b.lat - a.lat) * Math.PI) / 180;
    const dLng = ((b.lng - a.lng) * Math.PI) / 180;
    const aa =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((a.lat * Math.PI) / 180) * Math.cos((b.lat * Math.PI) / 180) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(aa), Math.sqrt(1 - aa));
    return R * c;
  }

  private estimateTravelTimeMinutes(distanceKm: number, speedKmh: number): number {
    const speed = Math.max(speedKmh, 5);
    return (distanceKm / speed) * 60;
  }

  private async getModelParameters(): Promise<ParameterMap> {
    const result = await this.db.query<QueryResultRow>(
      `SELECT key, value FROM model_parameters
       WHERE key = ANY($1)`,
      [[
        'ROUTE_UTILITY_TIME_WEIGHT',
        'ROUTE_UTILITY_RISK_WEIGHT',
        'ASSUMED_SPEED_KMH',
      ]],
    );

    const map = new Map(result.rows.map((r) => [String(r.key), Number(r.value)]));
    return {
      routeUtilityTimeWeight: map.get('ROUTE_UTILITY_TIME_WEIGHT') ?? 1,
      routeUtilityRiskWeight: map.get('ROUTE_UTILITY_RISK_WEIGHT') ?? 30,
      assumedSpeedKmh: map.get('ASSUMED_SPEED_KMH') ?? 32,
    };
  }
}
