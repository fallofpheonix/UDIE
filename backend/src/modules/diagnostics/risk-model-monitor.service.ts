import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';

export interface RiskModelHealth {
  meanRisk: number;
  stddevRisk: number;
  p95Risk: number;
  saturatedShare: number;
  healthy: boolean;
}

@Injectable()
export class RiskModelMonitor {
  constructor(private readonly db: DatabaseService) {}

  async evaluate(): Promise<RiskModelHealth> {
    const stats = await this.db.query<QueryResultRow>(`
      SELECT
        COALESCE(AVG(weight), 0) AS mean_risk,
        COALESCE(STDDEV_POP(weight), 0) AS stddev_risk,
        COALESCE(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY weight), 0) AS p95_risk,
        COALESCE(AVG(CASE WHEN weight >= 20 THEN 1 ELSE 0 END), 0) AS saturated_share
      FROM risk_cells
    `);

    const row = stats.rows[0] ?? {};
    const meanRisk = Number(row.mean_risk ?? 0);
    const stddevRisk = Number(row.stddev_risk ?? 0);
    const p95Risk = Number(row.p95_risk ?? 0);
    const saturatedShare = Number(row.saturated_share ?? 0);

    // Conservative default guardrails; can be moved to model_parameters later.
    const healthy = meanRisk < 15 && p95Risk < 60 && saturatedShare < 0.35;

    return { meanRisk, stddevRisk, p95Risk, saturatedShare, healthy };
  }
}
