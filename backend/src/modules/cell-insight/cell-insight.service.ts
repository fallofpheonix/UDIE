import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { SpatialService } from '../common/spatial.service';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class CellInsightService {
  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService,
  ) {}

  async getCellInsight(lat: number, lng: number) {
    const h3Index = this.spatial.getH3Index(lat, lng);

    const [risk, dominantEvent, recentCount, reliability, forecast] = await Promise.all([
      this.db.query<QueryResultRow>(
        `SELECT weight, updated_at
         FROM risk_cells
         WHERE h3_index = ($1::h3index)::bigint
         LIMIT 1`,
        [h3Index],
      ),
      this.db.query<QueryResultRow>(
        `SELECT event_type, COUNT(*)::int AS c
         FROM regional_geo_events_v
         WHERE h3_index = ($1::h3index)::bigint
           AND observed_at >= now() - interval '24 hours'
         GROUP BY event_type
         ORDER BY c DESC
         LIMIT 1`,
        [h3Index],
      ),
      this.db.query<QueryResultRow>(
        `SELECT COUNT(*)::int AS c
         FROM regional_geo_events_v
         WHERE h3_index = ($1::h3index)::bigint
           AND observed_at >= now() - interval '24 hours'`,
        [h3Index],
      ),
      this.db.query<QueryResultRow>(
        `SELECT reliability_score
         FROM reliability_cells
         WHERE h3_index = ($1::h3index)::bigint
         LIMIT 1`,
        [h3Index],
      ),
      this.db.query<QueryResultRow>(
        `SELECT forecast_30m
         FROM forecast_cells
         WHERE h3_index = ($1::h3index)::bigint
         ORDER BY updated_at DESC
         LIMIT 1`,
        [h3Index],
      ),
    ]);

    return {
      h3Index,
      riskScore: Number(risk.rows[0]?.weight ?? 0),
      dominantEventType: String(dominantEvent.rows[0]?.event_type ?? 'UNKNOWN'),
      recentEventCount: Number(recentCount.rows[0]?.c ?? 0),
      reliabilityScore: Number(reliability.rows[0]?.reliability_score ?? 0),
      forecastProbability: Number(forecast.rows[0]?.forecast_30m ?? 0),
      updatedAt: risk.rows[0]?.updated_at ?? null,
    };
  }
}
