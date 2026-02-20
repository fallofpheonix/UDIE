import { Controller, Get } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';

type FreshnessRow = QueryResultRow & {
  cell_freshness_seconds: number;
  max_stale_seconds: number;
};

@Controller('health')
export class HealthController {
  constructor(private readonly databaseService: DatabaseService) {}

  @Get()
  async health() {
    await this.databaseService.healthCheck();

    const freshness = await this.databaseService.query<FreshnessRow>(
      `SELECT
         EXTRACT(EPOCH FROM (now() - COALESCE(MAX(updated_at), now())))::DOUBLE PRECISION AS cell_freshness_seconds,
         COALESCE(
           (SELECT value FROM model_parameters WHERE key = 'MATERIALIZATION_STALE_SECONDS'),
           300.0
         ) AS max_stale_seconds
       FROM risk_cells`,
    );

    const row = freshness.rows[0];
    const stale = row.cell_freshness_seconds > row.max_stale_seconds;

    return {
      status: stale ? 'degraded' : 'ok',
      db: 'up',
      riskSurface: {
        stale,
        freshnessSeconds: Number(row.cell_freshness_seconds.toFixed(2)),
        maxAllowedSeconds: Number(row.max_stale_seconds.toFixed(2)),
      },
    };
  }
}
