import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { RouteRiskDto } from './dto/route-risk.dto';
import { RouteRiskResponseDto } from './dto/route-risk-response.dto';

type RouteRiskRow = QueryResultRow & {
  risk_score: number;
  event_count: number;
};

@Injectable()
export class RiskService {
  constructor(private readonly db: DatabaseService) {}

  async calculateRouteRisk(payload: RouteRiskDto): Promise<RouteRiskResponseDto> {
    if (!payload.coordinates || payload.coordinates.length < 2) {
      return { score: 0, level: 'LOW', eventCount: 0 };
    }

    const lineString =
      'LINESTRING(' +
      payload.coordinates.map((point) => `${point.lng} ${point.lat}`).join(', ') +
      ')';

    const result = await this.db.query<RouteRiskRow>(
      `
      SELECT risk_score, event_count
      FROM calculate_route_risk(
        ST_GeogFromText($1),
        $2
      );
      `,
      [lineString, payload.city],
    );

    const rawScore = Number(result.rows[0]?.risk_score ?? 0);
    const eventCount = Number(result.rows[0]?.event_count ?? 0);
    const normalized = Math.min(rawScore / 10.0, 1.0);

    let level: RouteRiskResponseDto['level'] = 'LOW';
    if (normalized >= 0.66) {
      level = 'HIGH';
    } else if (normalized >= 0.33) {
      level = 'MEDIUM';
    }

    return {
      score: Number(normalized.toFixed(3)),
      level,
      eventCount,
    };
  }
}
