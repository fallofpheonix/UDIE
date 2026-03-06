import { Injectable, Logger } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class ForecastService {
  private readonly logger = new Logger(ForecastService.name);

  constructor(private readonly db: DatabaseService) {}

  async rebuildForecastCells(): Promise<number> {
    const alpha = await this.getAlpha();

    const result = await this.db.query<QueryResultRow>(
      `WITH recent AS (
         SELECT h3_index, snapshot_time, risk_weight
         FROM risk_snapshots
         WHERE snapshot_time >= now() - interval '6 hours'
       ),
       ranked AS (
         SELECT h3_index, snapshot_time, risk_weight,
                ROW_NUMBER() OVER (PARTITION BY h3_index ORDER BY snapshot_time DESC) AS rn
         FROM recent
       ),
       pairs AS (
         SELECT
           h3_index,
           MAX(CASE WHEN rn = 1 THEN risk_weight END) AS w_now,
           MAX(CASE WHEN rn = 2 THEN risk_weight END) AS w_prev,
           COUNT(*)::int AS n
         FROM ranked
         WHERE rn <= 2
         GROUP BY h3_index
       ),
       forecasts AS (
         SELECT
           h3_index,
           (COALESCE(w_now, 0) * $1 + COALESCE(w_prev, COALESCE(w_now, 0)) * (1 - $1)) AS s,
           n
         FROM pairs
       )
       INSERT INTO forecast_cells (h3_index, forecast_30m, forecast_60m, source_points, updated_at)
       SELECT
         h3_index,
         GREATEST(0, s) AS forecast_30m,
         GREATEST(0, s * 1.15) AS forecast_60m,
         n,
         now()
       FROM forecasts
       ON CONFLICT (h3_index)
       DO UPDATE SET
         forecast_30m = EXCLUDED.forecast_30m,
         forecast_60m = EXCLUDED.forecast_60m,
         source_points = EXCLUDED.source_points,
         updated_at = EXCLUDED.updated_at
       RETURNING h3_index`,
      [alpha],
    );

    this.logger.log(`[FORECAST] rebuilt forecast_cells count=${result.rowCount ?? 0}`);
    return result.rowCount ?? 0;
  }

  async getForecast(h3Index: string) {
    const result = await this.db.query<QueryResultRow>(
      `SELECT (h3_index::h3index)::text AS h3_index,
              forecast_30m,
              forecast_60m,
              source_points,
              updated_at
       FROM forecast_cells
       WHERE h3_index = ($1::h3index)::bigint
       LIMIT 1`,
      [h3Index],
    );

    if (result.rows.length === 0) {
      return {
        h3Index,
        forecast_30m: 0,
        forecast_60m: 0,
        sourcePoints: 0,
        updatedAt: null,
      };
    }

    const row = result.rows[0];
    return {
      h3Index: String(row.h3_index),
      forecast_30m: Number(row.forecast_30m),
      forecast_60m: Number(row.forecast_60m),
      sourcePoints: Number(row.source_points),
      updatedAt: row.updated_at,
    };
  }

  private async getAlpha(): Promise<number> {
    const result = await this.db.query<QueryResultRow>(
      `SELECT value FROM model_parameters WHERE key = 'FORECAST_ALPHA' LIMIT 1`,
    );
    const alpha = Number(result.rows[0]?.value ?? 0.35);
    return Number.isFinite(alpha) && alpha > 0 && alpha < 1 ? alpha : 0.35;
  }
}
