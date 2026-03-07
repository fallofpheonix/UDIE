import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { ObservabilityService } from '../common/observability.service';

@Injectable()
export class PerformanceSentinel {
  constructor(
    private readonly db: DatabaseService,
    private readonly obs: ObservabilityService,
  ) {}

  async collectSnapshot() {
    const dbStats = await this.db.query<QueryResultRow>(`
      SELECT
        COALESCE(SUM(blks_hit), 0)::float AS blks_hit,
        COALESCE(SUM(blks_read), 0)::float AS blks_read
      FROM pg_stat_database
    `);

    const row = dbStats.rows[0] ?? {};
    const hits = Number(row.blks_hit ?? 0);
    const reads = Number(row.blks_read ?? 0);
    const bufferHitRatio = hits + reads > 0 ? hits / (hits + reads) : 1;

    const metricSnapshot = this.obs.snapshot();

    return {
      riskLatencyAvgMs: metricSnapshot.riskEvalLatencyAvgSec * 1000,
      gridRefreshAvgMs: metricSnapshot.riskGridRefreshAvgSec * 1000,
      eventsIngestedTotal: metricSnapshot.eventsIngestedTotal,
      riskGridSize: metricSnapshot.riskGridSize,
      bufferHitRatio,
      healthy: metricSnapshot.riskEvalLatencyAvgSec <= 0.005 && bufferHitRatio >= 0.9,
    };
  }
}
