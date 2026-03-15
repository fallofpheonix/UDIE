import { Controller, Get, Param, Logger } from '@nestjs/common';
import { RiskGridService } from '../modules/risk/risk-grid.service';
import { ReliabilityService } from '../modules/reliability/reliability.service';
import { ForecastService } from '../modules/forecast/forecast.service';
import { DatabaseService } from '../database/database.service';

@Controller('intelligence/cell')
export class CellIntelligenceController {
    private readonly logger = new Logger(CellIntelligenceController.name);

    constructor(
        private readonly riskGrid: RiskGridService,
        private readonly reliability: ReliabilityService,
        private readonly forecast: ForecastService,
        private readonly db: DatabaseService,
    ) { }

    @Get(':h3Index')
    async getCellIntelligence(@Param('h3Index') h3Index: string) {
        const start = performance.now();
        const now = new Date();

        try {
            // Parallel execution for O(1) bounded latency
            const [risk, reliability, forecast, history] = await Promise.all([
                this.riskGrid.getWeight(h3Index),
                this.db.query(`
          SELECT reliability_score, disruption_count, avg_severity 
          FROM reliability_cells WHERE h3_index = $1::bigint
        `, [h3Index]),
                this.forecast.getForecast(h3Index),
                this.db.query(`
          SELECT event_type, payload->>'severity_hint' as severity, created_at 
          FROM regional_events_log 
          WHERE (payload->>'h3_index')::bigint = $1::bigint
          ORDER BY created_at DESC LIMIT 5
        `, [h3Index])
            ]);

            const relData = reliability.rows[0] || { reliability_score: 1.0, disruption_count: 0, avg_severity: 0 };

            // Explanation Logic (Heuristic based for MVP)
            let explanation = "This cell is currently stable.";
            if (risk > 5) {
                explanation = "High risk detected due to active disruptions.";
            } else if (relData.reliability_score < 0.7) {
                explanation = "Frequent historical disruptions make this cell unreliable.";
            } else if (forecast.forecast_30m > 0.4) {
                explanation = "High probability of disruption forecasted for this time window.";
            }

            const duration = (performance.now() - start).toFixed(2);
            this.logger.debug(`[CELL_INTEL] index=${h3Index} latency=${duration}ms`);

            return {
                h3Index,
                summary: {
                    riskScore: risk,
                    reliabilityScore: parseFloat(relData.reliability_score),
                    forecastProbability: forecast.forecast_30m,
                    explanation
                },
                details: {
                    historicalCount: parseInt(relData.disruption_count),
                    avgSeverity: parseFloat(relData.avg_severity),
                    recentEvents: history.rows
                },
                metadata: {
                    latencyMs: parseFloat(duration),
                    timestamp: now.toISOString()
                }
            };
        } catch (error: unknown) {
            this.logger.error(`[CELL_INTEL] Failed to inspect cell ${h3Index}: ${error instanceof Error ? error.message : String(error)}`);
            throw error;
        }
    }
}
