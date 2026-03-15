import { Injectable, Logger } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import { RiskGridService } from './risk-grid.service';
import { CellRiskSummary, RiskSurfaceCacheService } from './risk-surface-cache.service';

type ActiveEventRow = QueryResultRow & {
  event_id: string;
  h3_cell: string;
  event_type: string;
  severity: number;
  confidence: number;
  observed_at: string | Date | null;
};

type ModelParameterRow = QueryResultRow & {
  key: string;
  value: number;
};

export interface RiskFieldRefreshStats {
  eventCount: number;
  cellCount: number;
  tauSeconds: number;
  diffusionRings: number;
  durationMs: number;
}

interface RiskFieldRefreshOptions {
  evaluationTimeMs?: number;
}

@Injectable()
export class SpatialRiskFieldService {
  private readonly logger = new Logger(SpatialRiskFieldService.name);
  private readonly defaultTauSeconds = 2 * 60 * 60;
  private readonly defaultDiffusionRings = 3;
  private readonly minPersistedWeight = 0.001;
  private readonly maxPersistedWeight = 0.999999;

  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService,
    private readonly riskGrid: RiskGridService,
    private readonly riskSurfaceCache: RiskSurfaceCacheService,
  ) { }

  async refreshRiskField(options: RiskFieldRefreshOptions = {}): Promise<RiskFieldRefreshStats> {
    const startedAt = performance.now();
    const [events, parameters] = await Promise.all([
      this.loadActiveEvents(),
      this.loadModelParameters(),
    ]);

    const tauSeconds = this.resolveTauSeconds(parameters);
    const diffusionRings = this.resolveDiffusionRings(parameters);
    const evaluationTimeMs = options.evaluationTimeMs ?? Date.now();
    const { weights, summaries } = this.computeWeights(events, tauSeconds, diffusionRings, evaluationTimeMs);

    await this.persistWeights(weights);
    this.riskGrid.replaceAll(weights);
    await this.riskSurfaceCache.replaceSurface(weights, summaries);

    const durationMs = Number((performance.now() - startedAt).toFixed(2));
    this.logger.log(
      `[RISK_FIELD] refreshed events=${events.length} cells=${weights.size} tau_seconds=${tauSeconds} rings=${diffusionRings} duration_ms=${durationMs}`,
    );

    return {
      eventCount: events.length,
      cellCount: weights.size,
      tauSeconds,
      diffusionRings,
      durationMs,
    };
  }

  private async loadActiveEvents(): Promise<ActiveEventRow[]> {
    const result = await this.db.queryRead<ActiveEventRow>(
      `WITH latest_events AS (
         SELECT DISTINCT ON (event_id)
           event_id,
           (h3_index::h3index)::text AS h3_cell,
           event_type,
           severity::double precision AS severity,
           confidence::double precision AS confidence,
           observed_at
         FROM regional_geo_events_v
         WHERE status = 'ACTIVE'
         ORDER BY event_id, version DESC
       )
       SELECT event_id, h3_cell, event_type, severity, confidence, observed_at
       FROM latest_events`,
    );
    return result.rows;
  }

  private async loadModelParameters(): Promise<Map<string, number>> {
    const result = await this.db.queryRead<ModelParameterRow>(
      `SELECT key, value
       FROM model_parameters
       WHERE key IN ('TEMPORAL_TAU_SECONDS', 'DIFFUSION_ROUNDS')`,
    );
    const parameters = new Map<string, number>();
    for (const row of result.rows) {
      parameters.set(row.key, Number(row.value));
    }
    return parameters;
  }

  private resolveTauSeconds(parameters: Map<string, number>): number {
    const fromDb = Number(parameters.get('TEMPORAL_TAU_SECONDS'));
    if (Number.isFinite(fromDb) && fromDb > 0) {
      return fromDb;
    }
    return this.defaultTauSeconds;
  }

  private resolveDiffusionRings(parameters: Map<string, number>): number {
    const fromDb = Number(parameters.get('DIFFUSION_ROUNDS'));
    if (Number.isFinite(fromDb) && fromDb >= 1) {
      return Math.min(4, Math.round(fromDb));
    }
    return this.defaultDiffusionRings;
  }

  private computeWeights(
    events: ActiveEventRow[],
    tauSeconds: number,
    diffusionRings: number,
    evaluationTimeMs: number,
  ): { weights: Map<string, number>; summaries: Map<string, CellRiskSummary> } {
    const weights = new Map<string, number>();
    const summaryBuilders = new Map<string, { eventIds: Set<string>; hazardWeights: Map<string, number> }>();

    for (const event of events) {
      const originCell = event.h3_cell;
      if (!originCell) {
        continue;
      }

      const severity = Number(event.severity ?? 0);
      const confidence = Number(event.confidence ?? 0);
      if (!Number.isFinite(severity) || !Number.isFinite(confidence) || severity <= 0 || confidence <= 0) {
        continue;
      }

      const observedAtMs = event.observed_at ? new Date(event.observed_at).getTime() : evaluationTimeMs;
      const ageSeconds = Math.max(0, (evaluationTimeMs - observedAtMs) / 1000);
      const temporalDecay = Math.exp(-ageSeconds / tauSeconds);
      const originWeight = severity * confidence * temporalDecay;

      if (originWeight < this.minPersistedWeight) {
        continue;
      }

      for (const cell of this.spatial.getInfluenceNeighbors(originCell, diffusionRings)) {
        const gridDistance = this.spatial.getGridDistance(originCell, cell);
        const spatialKernel = this.spatial.getInfluenceWeight(gridDistance);
        const contribution = originWeight * spatialKernel;
        if (contribution < this.minPersistedWeight) {
          continue;
        }
        const nextWeight = (weights.get(cell) ?? 0) + contribution;
        weights.set(cell, Number(nextWeight.toFixed(6)));

        const builder = summaryBuilders.get(cell) ?? {
          eventIds: new Set<string>(),
          hazardWeights: new Map<string, number>(),
        };
        builder.eventIds.add(event.event_id);
        builder.hazardWeights.set(
          event.event_type,
          (builder.hazardWeights.get(event.event_type) ?? 0) + contribution,
        );
        summaryBuilders.set(cell, builder);
      }
    }

    const summaries = new Map<string, CellRiskSummary>();
    for (const [cell, builder] of summaryBuilders) {
      const hazardTypes = Array.from(builder.hazardWeights.entries())
        .sort((a, b) => b[1] - a[1])
        .map(([type]) => type);
      summaries.set(cell, {
        eventCount: builder.eventIds.size,
        hazardTypes,
        dominantHazard: hazardTypes[0] ?? null,
      });
    }

    return { weights, summaries };
  }

  private async persistWeights(weights: Map<string, number>): Promise<void> {
    const deduped = new Map<string, number>();
    for (const [cell, weight] of weights.entries()) {
      if (!Number.isFinite(weight) || weight < this.minPersistedWeight) {
        continue;
      }
      const dbIndex = this.spatial.toDbIndex(cell);
      deduped.set(dbIndex, Number(((deduped.get(dbIndex) ?? 0) + weight).toFixed(6)));
    }

    for (const [dbIndex, rawWeight] of deduped.entries()) {
      const normalized = Math.min(
        this.maxPersistedWeight,
        Math.max(0, 1 - Math.exp(-rawWeight)),
      );
      deduped.set(dbIndex, Number(normalized.toFixed(6)));
    }

    await this.db.withTransaction(async (client) => {
      await client.query(`SELECT set_config('udie.allow_derived_mutation', 'true', true)`);
      await client.query('DELETE FROM risk_cells');

      if (deduped.size > 0) {
        const dbIndexes = Array.from(deduped.keys());
        const numericWeights = Array.from(deduped.values());
        await client.query(
          `WITH incoming AS (
             SELECT unnest($1::bigint[]) AS h3_index, unnest($2::float8[]) AS weight
           )
           INSERT INTO risk_cells (h3_index, weight, updated_at)
           SELECT h3_index, SUM(weight), now()
           FROM incoming
           GROUP BY h3_index
           ON CONFLICT (h3_index)
           DO UPDATE SET
             weight = EXCLUDED.weight,
             updated_at = EXCLUDED.updated_at`,
          [dbIndexes, numericWeights],
        );
      }

      await client.query(`SELECT set_config('udie.allow_derived_mutation', 'false', true)`);
    });
  }
}
