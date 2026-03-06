import { Injectable, Logger } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../database/database.service';
import { RiskGridService } from '../modules/risk/risk-grid.service';
import { SpatialService } from '../modules/common/spatial.service';
import {
  IntelligenceInsight,
  IntelligenceQuery,
  IntelligenceRuleConfig,
  RiskCell,
} from './IntelligenceTypes';
import { hotspotInsight, recurringInsight, spikeInsight } from './IntelligenceRules';

@Injectable()
export class IntelligenceService {
  private readonly logger = new Logger(IntelligenceService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly inMemRisk: RiskGridService,
    private readonly spatial: SpatialService,
  ) { }

  /**
   * Orchestrates the pattern detection loop.
   * Law: Intelligence is asynchronous and does not block ingestion.
   */
  async runAnalysis(): Promise<number> {
    this.logger.log('[INTEL] Starting nationwide pattern analysis...');
    try {
      const config = await this.getConfig();
      const activeIndices = this.inMemRisk.getAllActiveIndices();

      let total = 0;

      for (const h3Index of activeIndices) {
        const weight = this.inMemRisk.getWeight(h3Index);

        // 1. Hotspot Detection (In-Memory Neighbors)
        const neighbors = this.spatial.getInfluenceNeighbors(h3Index, 1);
        const highRiskNeighbors = neighbors.filter(n => this.inMemRisk.getWeight(n) >= config.hotspotThreshold).length;

        const hotspot = hotspotInsight(h3Index, weight, highRiskNeighbors, config);
        if (hotspot) {
          await this.persistEvent(hotspot, {
            score: weight,
            threshold: config.hotspotThreshold,
            windowMinutes: config.spikeWindowMinutes,
            eventCount: highRiskNeighbors,
            metadata: { highRiskNeighbors },
          });
          total += 1;
        }

        // 2. Spike Detection (Needs historical state from DB)
        const previousWeight = await this.readPreviousWeight(h3Index, config.spikeWindowMinutes);
        const spike = spikeInsight(h3Index, previousWeight, weight, config);
        if (spike) {
          const ratio = previousWeight && previousWeight > 0 ? weight / previousWeight : 0;
          await this.persistEvent(spike, {
            score: ratio,
            threshold: config.spikeMultiplier,
            windowMinutes: config.spikeWindowMinutes,
            eventCount: 1,
            metadata: { previousWeight, currentWeight: weight },
          });
          total += 1;
        }

        // 3. Recurring Events (Needs historical event data from DB)
        const count = await this.countRecurringEvents(h3Index);
        const recurring = recurringInsight(h3Index, count, config);
        if (recurring) {
          await this.persistEvent(recurring, {
            score: count,
            threshold: config.recurringThreshold24h,
            windowMinutes: 24 * 60,
            eventCount: count,
            metadata: { recurringCount24h: count },
          });
          total += 1;
        }

        // Update cell state in DB for next spike detection
        await this.updateCellState(h3Index, weight);
      }

      await this.pruneOldInsights();
      this.logger.log(`[INTEL] Analysis complete. Persistent insights: ${total}`);
      return total;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.error(`[INTEL] Loop failed: ${message}`);
      return 0;
    }
  }

  async listRecentInsights(query: IntelligenceQuery) {
    const limit = Math.min(Math.max(query.limit ?? 50, 1), 200);
    const result = await this.db.query<QueryResultRow>(`
      SELECT h3_index::text AS h3_index, pattern_type as type, severity, metadata, created_at
      FROM intelligence_events
      WHERE ($2::text IS NULL OR h3_cell_to_parent(h3_index::h3index, 6)::text = $2)
      ORDER BY created_at DESC
      LIMIT $1
    `, [limit, query.regionId ?? null]);

    return result.rows.map((row) => ({
      type: String(row.type),
      cell: String(row.h3_index),
      severity: String(row.severity),
      description: String((row.metadata as { description?: string } | null)?.description ?? ''),
      createdAt: row.created_at as Date,
    }));
  }

  private async getConfig(): Promise<IntelligenceRuleConfig> {
    const result = await this.db.query<QueryResultRow>(
      `SELECT key, value
       FROM model_parameters
       WHERE key = ANY($1)`,
      [[
        'INTEL_HOTSPOT_THRESHOLD',
        'INTEL_HOT_NEIGHBORS_MIN',
        'INTEL_RECURRING_EVENTS_24H',
        'INTEL_SPIKE_MULTIPLIER',
        'INTEL_SPIKE_WINDOW_MINUTES',
        'INTEL_SCAN_LIMIT',
      ]],
    );

    const map = new Map(result.rows.map((r) => [String(r.key), Number(r.value)]));
    return {
      hotspotThreshold: map.get('INTEL_HOTSPOT_THRESHOLD') ?? 8.0,
      hotspotNeighborCount: Math.round(map.get('INTEL_HOT_NEIGHBORS_MIN') ?? 3),
      recurringThreshold24h: Math.round(map.get('INTEL_RECURRING_EVENTS_24H') ?? 5),
      spikeMultiplier: map.get('INTEL_SPIKE_MULTIPLIER') ?? 3.0,
      spikeWindowMinutes: Math.round(map.get('INTEL_SPIKE_WINDOW_MINUTES') ?? 10),
      scanLimit: Math.round(map.get('INTEL_SCAN_LIMIT') ?? 500),
    };
  }

  private async countRecurringEvents(h3Index: string): Promise<number> {
    const result = await this.db.query<QueryResultRow>(`
      SELECT COUNT(*)::int AS count
      FROM regional_geo_events_v
      WHERE h3_index = ($1::h3index)::bigint
        AND observed_at >= now() - interval '24 hours'
    `, [h3Index]);
    return Number(result.rows[0]?.count ?? 0);
  }

  private async readPreviousWeight(h3Index: string, windowMinutes: number): Promise<number | null> {
    const result = await this.db.query<QueryResultRow>(`
      SELECT last_weight
      FROM intelligence_cell_state
      WHERE h3_index = ($1::h3index)::bigint
        AND updated_at >= now() - make_interval(mins => $2)
      LIMIT 1
    `, [h3Index, windowMinutes]);
    const value = result.rows[0]?.last_weight;
    return value === undefined || value === null ? null : Number(value);
  }

  private async updateCellState(h3Index: string, weight: number): Promise<void> {
    await this.db.query(`
      INSERT INTO intelligence_cell_state (h3_index, last_weight, updated_at)
      VALUES (($1::h3index)::bigint, $2, now())
      ON CONFLICT (h3_index) DO UPDATE SET last_weight = $2, updated_at = now()
    `, [h3Index, weight]);
  }

  private async persistEvent(
    insight: IntelligenceInsight,
    metrics: {
      score: number;
      threshold: number;
      windowMinutes: number;
      eventCount: number;
      metadata: Record<string, unknown>;
    },
  ): Promise<void> {
    await this.db.query(
      `INSERT INTO intelligence_events (
         h3_index, pattern_type, severity, score, threshold, window_minutes, event_count, metadata
       ) VALUES (($1::h3index)::bigint, $2, $3, $4, $5, $6, $7, $8::jsonb)`,
      [
        insight.h3Index,
        insight.type,
        insight.severity,
        metrics.score,
        metrics.threshold,
        metrics.windowMinutes,
        metrics.eventCount,
        JSON.stringify({ description: insight.description, ...metrics.metadata }),
      ],
    );
  }

  private async pruneOldInsights(): Promise<void> {
    await this.db.query(`DELETE FROM intelligence_events WHERE created_at < now() - interval '48 hours'`);
  }
}
