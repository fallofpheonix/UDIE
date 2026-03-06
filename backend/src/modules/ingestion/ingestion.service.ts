import { Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import { PartitionManagementService } from '../common/partition-management.service';
import {
  SocialEventParserService,
  SocialPostInput,
} from './social-event-parser.service';

export interface RawEvent {
  source_id: string;
  source_type: string;
  observed_at?: string;
  lat: number;
  lng: number;
  event_type: string;
  severity_hint?: number;
  confidence_hint?: number;
  text?: string;
}

export interface IngestionResult {
  status: 'SUCCESS' | 'REJECTED' | 'DUPLICATE' | 'FAILED';
  reason?: string;
  eventId?: string;
  opType?: string;
  logId?: string;
  idempotencyKey?: string;
}

import { ObservabilityService } from '../common/observability.service';

@Injectable()
export class IngestionService {
  private readonly logger = new Logger(IngestionService.name);
  private readonly batchSize = 100;
  private readonly flushWindowMs = 1_000;
  private readonly allowedEventTypes = new Set([
    'ACCIDENT',
    'CONSTRUCTION',
    'METRO_WORK',
    'WATER_LOGGING',
    'PROTEST',
    'HEAVY_TRAFFIC',
    'ROAD_BLOCK',
  ]);
  private bufferedEvents: RawEvent[] = [];
  private flushTimer: NodeJS.Timeout | null = null;
  private densityAlpha = 0.3;
  private densityAlphaLoadedAt = 0;

  constructor(
    private readonly db: DatabaseService,
    private readonly parser: SocialEventParserService,
    private readonly spatial: SpatialService,
    private readonly partitionManager: PartitionManagementService,
    private readonly observability: ObservabilityService,
  ) { }

  async processSocialPost(post: SocialPostInput): Promise<IngestionResult> {
    const parsed = await this.parser.parse(post);
    if (!parsed) {
      return { status: 'REJECTED', reason: 'UNPARSABLE_POST' };
    }

    return this.processRawEvent({
      source_id: parsed.source_id,
      source_type: 'SOCIAL_MEDIA',
      observed_at: parsed.observed_at,
      lat: parsed.lat,
      lng: parsed.lng,
      event_type: parsed.event_type,
      severity_hint: parsed.severity_hint,
      text: parsed.text,
    });
  }

  queueRawEvent(event: RawEvent): void {
    this.bufferedEvents.push(event);
    if (this.bufferedEvents.length >= this.batchSize) {
      void this.flushBufferedEvents();
      return;
    }
    if (!this.flushTimer) {
      this.flushTimer = setTimeout(() => {
        void this.flushBufferedEvents();
      }, this.flushWindowMs);
    }
  }

  async processRawEvents(events: RawEvent[]): Promise<IngestionResult[]> {
    const start = performance.now();
    const results: IngestionResult[] = [];

    for (const event of events) {
      results.push(await this.processOne(event));
    }

    const durationMs = Number((performance.now() - start).toFixed(2));
    this.logger.log(
      `[INGEST] BATCH complete size=${events.length} duration_ms=${durationMs}`,
    );
    return results;
  }

  async processRawEvent(event: RawEvent): Promise<IngestionResult> {
    const results = await this.processRawEvents([event]);
    return results[0];
  }

  private async processOne(event: RawEvent): Promise<IngestionResult> {
    const { source_id, source_type, lat, lng, event_type, severity_hint, text } = event;
    const start = performance.now();
    const normalizedType = event_type.toUpperCase().trim();
    const normalizedSource = source_type?.toUpperCase().trim() || 'USER_REPORT';
    const normalizedObservedAt = this.normalizeObservedAt(event.observed_at);

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      this.logger.warn(`[INGEST] status=REJECTED source=${source_id} reason=MISSING_GEOMETRY`);
      return { status: 'REJECTED', reason: 'MISSING_GEOMETRY' };
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return { status: 'REJECTED', reason: 'OUT_OF_RANGE_GEOMETRY' };
    }
    if (!this.allowedEventTypes.has(normalizedType)) {
      return { status: 'REJECTED', reason: 'UNSUPPORTED_EVENT_TYPE' };
    }

    // 1. Derive Regional Partition (H3 Res 6)
    const h3Parent = this.spatial.getRegionId(lat, lng);
    await this.partitionManager.ensurePartition(h3Parent);

    const idempotencyKey = this.makeIdempotencyKey({
      source_id,
      source_type: normalizedSource,
      observed_at: normalizedObservedAt,
      lat,
      lng,
      event_type: normalizedType,
      severity_hint,
      text,
    }, h3Parent);

    try {
      // 2. Insert into Regional Log (Law 2: Partition by h3_parent)
      const logResult = await this.db.query(
        `INSERT INTO regional_events_log (id, h3_parent, log_type, source, source_ref, source_type, payload)
         VALUES (gen_random_uuid(), $1, 'INGESTED', $2, $3, $4, $5)
         ON CONFLICT DO NOTHING
         RETURNING id`,
        [h3Parent, 'API', source_id, normalizedSource, JSON.stringify(event)],
      );

      await this.applyIncrementalRiskUpdate(lat, lng, severity_hint ?? 1);

      const ingestLogId = logResult.rows[0]?.id as string | undefined;
      if (!ingestLogId) {
        return { status: 'SUCCESS', reason: 'MAYBE_DUPLICATE', idempotencyKey };
      }

      // 3. Metrics
      this.observability.eventsIngested.inc({
        source_type: normalizedSource,
        event_type: normalizedType,
      });

      const duration = (performance.now() - start).toFixed(2);
      this.logger.log(
        `[INGEST] status=SUCCESS source=${source_id} latency_ms=${duration} log_id=${ingestLogId} region=${h3Parent}`,
      );

      return {
        status: 'SUCCESS',
        logId: ingestLogId,
        idempotencyKey,
      };
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.error(`[INGEST] status=FAILED source=${source_id} reason=${message}`);
      // Log failure to regional log if possible
      await this.db.query(
        `INSERT INTO regional_events_log (id, h3_parent, log_type, source, source_ref, payload)
         VALUES (gen_random_uuid(), $1, 'FAILED', $2, $3, $4)`,
        [h3Parent, 'TWITTER', source_id, JSON.stringify({ ...event, error: message })],
      ).catch(() => { });

      return { status: 'FAILED', reason: message, idempotencyKey };
    }
  }

  private async flushBufferedEvents(): Promise<void> {
    if (this.flushTimer) {
      clearTimeout(this.flushTimer);
      this.flushTimer = null;
    }
    if (this.bufferedEvents.length === 0) {
      return;
    }

    const batch = this.bufferedEvents.splice(0, this.batchSize);
    await this.processRawEvents(batch);
  }

  private normalizeObservedAt(value?: string): string {
    if (!value) {
      return new Date().toISOString();
    }
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
      return new Date().toISOString();
    }
    return parsed.toISOString();
  }

  private makeIdempotencyKey(event: RawEvent, regionId: string): string {
    return createHash('sha256')
      .update(
        `${regionId}|${event.source_id}|${event.event_type}|${event.lat.toFixed(6)}|${event.lng.toFixed(6)}|${this.normalizeObservedAt(event.observed_at)}|${event.text ?? ''}`,
      )
      .digest('hex');
  }

  private async applyIncrementalRiskUpdate(
    lat: number,
    lng: number,
    severity: number,
    confidence = 1,
  ): Promise<void> {
    const originCell = this.spatial.getH3Index(lat, lng);
    const neighbors = this.spatial.getInfluenceNeighbors(originCell, 3);

    const neighborCells = this.spatial.getInfluenceNeighbors(originCell, 1);
    const neighborEventCountResult = await this.db.query<{ count: number }>(
      `SELECT COUNT(*)::int AS count
       FROM risk_cells
       WHERE h3_index = ANY(
         ARRAY(
           SELECT (cell::h3index)::bigint
           FROM unnest($1::text[]) AS cell
         )
       )
         AND weight > 0`,
      [neighborCells],
    );

    const neighborEventCount = Number(neighborEventCountResult.rows[0]?.count ?? 0);
    const alpha = await this.getDensityAlpha();
    const densityFactor = 1 + alpha * Math.log(1 + neighborEventCount);
    const baseWeight = severity * confidence;

    for (const neighbor of neighbors) {
      const distance = this.spatial.getGridDistance(originCell, neighbor);
      const influence = this.spatial.getInfluenceWeight(distance);
      if (influence <= 0) {
        continue;
      }

      const delta = baseWeight * densityFactor * influence;
      await this.db.query(
        `INSERT INTO risk_cells (h3_index, weight, updated_at)
         VALUES (($1::h3index)::bigint, $2, now())
         ON CONFLICT (h3_index)
         DO UPDATE SET
           weight = GREATEST(0, risk_cells.weight + EXCLUDED.weight),
           updated_at = EXCLUDED.updated_at`,
        [neighbor, delta],
      );
    }
  }

  private async getDensityAlpha(): Promise<number> {
    const now = Date.now();
    if (now - this.densityAlphaLoadedAt < 60_000) {
      return this.densityAlpha;
    }

    const result = await this.db.query<{ value: number }>(
      `SELECT value
       FROM model_parameters
       WHERE key = 'DENSITY_ALPHA'
       LIMIT 1`,
    );

    const value = Number(result.rows[0]?.value);
    this.densityAlpha = Number.isFinite(value) && value >= 0 ? value : 0.3;
    this.densityAlphaLoadedAt = now;
    return this.densityAlpha;
  }
}
