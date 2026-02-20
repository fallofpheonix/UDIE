import { Injectable, Logger } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { RouteRiskDto } from './dto/route-risk.dto';
import { RouteRiskResponseDto } from './dto/route-risk-response.dto';

type RouteRiskRow = QueryResultRow & {
  risk_score: number;
  event_count: number;
};

type ModelParamRow = QueryResultRow & {
  key: string;
  value: number;
};

@Injectable()
export class RiskService {
  private readonly logger = new Logger(RiskService.name);

  constructor(private readonly db: DatabaseService) { }

  async calculateRouteRisk(payload: RouteRiskDto): Promise<RouteRiskResponseDto> {
    const { coordinates, city } = payload;
    const start = performance.now();
    const requestID = Math.random().toString(36).substring(7);
    const config = await this.getRiskConfig();

    if (!coordinates || coordinates.length < 2) {
      this.logger.warn(`[REQ:${requestID}] Insufficient coordinates for risk calculation in city: ${city}`);
      return { score: 0, level: 'LOW', eventCount: 0 };
    }

    if (coordinates.length > config.maxVertices) {
      this.logger.error(`[REQ:${requestID}] Route exceeds vertex limit (${coordinates.length} > ${config.maxVertices})`);
      throw new Error(`Route too complex. Max vertices allowed: ${config.maxVertices}`);
    }

    // Basic distance estimation (sum of segments)
    let totalDist = 0;
    for (let i = 0; i < coordinates.length - 1; i++) {
      const p1 = coordinates[i];
      const p2 = coordinates[i + 1];
      totalDist += Math.sqrt(Math.pow(p2.lat - p1.lat, 2) + Math.pow(p2.lng - p1.lng, 2));
    }

    // Crude approx (1 degree ~ 111km)
    if (totalDist * 111 > config.maxDistanceKm) {
      this.logger.error(`[REQ:${requestID}] Route exceeds distance limit (${(totalDist * 111).toFixed(2)}km > ${config.maxDistanceKm}km)`);
      throw new Error(`Route too long. Max distance: ${config.maxDistanceKm}km`);
    }

    this.logger.log(`[Risk v2] [REQ:${requestID}] Calculating for ${city} with ${coordinates.length} points`);

    const lineString =
      'LINESTRING(' +
      coordinates.map((point) => `${point.lng} ${point.lat}`).join(', ') +
      ')';

    try {
      const result = await this.db.query<RouteRiskRow>(
        `SELECT raw_risk_score as risk_score, cell_count as event_count FROM calculate_route_risk_v3(ST_GeogFromText($1));`,
        [lineString],
      );

      const rawScore = Number(result.rows[0]?.risk_score ?? 0);
      const eventCount = Number(result.rows[0]?.event_count ?? 0);

      const normalized = 1 - Math.exp(-rawScore / config.sigmoidK);

      const level: RouteRiskResponseDto['level'] =
        normalized >= 0.7 ? 'HIGH' : normalized >= 0.35 ? 'MEDIUM' : 'LOW';

      const latency = (performance.now() - start).toFixed(2);

      // Day 1-2: Instrument Reality - Baseline performance logging for CSV extraction
      // Format: BASELINE,points,latency_ms,events_scanned,rows_returned
      this.logger.log(`[BASELINE] points:${coordinates.length}, latency:${latency}ms, events_scanned:${eventCount}, rows_returned:1`);
      this.logger.log(`[Risk v2] [RES:${requestID}] Latency: ${latency}ms, Raw: ${rawScore.toFixed(2)}, Norm: ${normalized.toFixed(4)}, Level: ${level}, Events: ${eventCount}`);

      return {
        score: Number(normalized.toFixed(3)),
        level,
        eventCount,
        modelVersion: 2,
        latencyMs: parseFloat(latency),
      };
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      const stack = error instanceof Error ? error.stack : undefined;
      this.logger.error(`[Risk v2] [ERR:${requestID}] Database error: ${message}`, stack);
      throw error;
    }
  }

  private async getRiskConfig(): Promise<{
    sigmoidK: number;
    maxVertices: number;
    maxDistanceKm: number;
  }> {
    const result = await this.db.query<ModelParamRow>(
      `SELECT key, value
       FROM model_parameters
       WHERE key = ANY($1)`,
      [['SIGMOID_K', 'MAX_ROUTE_VERTICES', 'MAX_ROUTE_DISTANCE_KM']],
    );

    const map = new Map(result.rows.map((row) => [row.key, Number(row.value)]));
    return {
      sigmoidK: map.get('SIGMOID_K') ?? 20.0,
      maxVertices: Math.round(map.get('MAX_ROUTE_VERTICES') ?? 1000),
      maxDistanceKm: map.get('MAX_ROUTE_DISTANCE_KM') ?? 50.0,
    };
  }
}
