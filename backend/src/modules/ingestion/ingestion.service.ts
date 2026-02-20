import { Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { DatabaseService } from '../../database/database.service';
import {
  SocialEventParserService,
  SocialPostInput,
} from './social-event-parser.service';

export interface RawEvent {
  source_id: string;
  observed_at?: string;
  lat: number;
  lng: number;
  event_type: string;
  severity_hint?: number;
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

  constructor(
    private readonly db: DatabaseService,
    private readonly parser: SocialEventParserService,
  ) {}

  async processSocialPost(post: SocialPostInput): Promise<IngestionResult> {
    const parsed = await this.parser.parse(post);
    if (!parsed) {
      return { status: 'REJECTED', reason: 'UNPARSABLE_POST' };
    }

    return this.processRawEvent({
      source_id: parsed.source_id,
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
    const { source_id, lat, lng, event_type, severity_hint, text } = event;
    const start = performance.now();
    const normalizedType = event_type.toUpperCase().trim();
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

    const idempotencyKey = this.makeIdempotencyKey({
      source_id,
      observed_at: normalizedObservedAt,
      lat,
      lng,
      event_type: normalizedType,
      severity_hint,
      text,
    });

    try {
      const logResult = await this.db.query(
        `INSERT INTO events_log (log_type, source, source_ref, idempotency_key, payload)
         VALUES ('INGESTED', $1, $2, $3, $4)
         ON CONFLICT (idempotency_key) WHERE log_type = 'INGESTED'
         DO NOTHING
         RETURNING id`,
        ['TWITTER', source_id, idempotencyKey, JSON.stringify(event)],
      );

      const ingestLogId = logResult.rows[0]?.id as string | undefined;
      if (!ingestLogId) {
        return { status: 'DUPLICATE', reason: 'IDEMPOTENT_HIT', idempotencyKey };
      }

      const result = await this.db.query(
        'SELECT * FROM upsert_geo_event_v2($1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, $6, $7, $8)',
        [
          normalizedType,
          severity_hint ?? 1,
          0.7,
          lng,
          lat,
          'DEL',
          source_id,
          text ?? null,
        ],
      );

      const eventId = result.rows[0]?.event_id as string;
      const opType = result.rows[0]?.op_type as string;

      await this.db.query(
        `INSERT INTO events_log (log_type, source, source_ref, parent_log_id, payload)
         VALUES ('PROCESSED', $1, $2, $3, $4)`,
        [
          'TWITTER',
          source_id,
          ingestLogId,
          JSON.stringify({
            event_id: eventId,
            op_type: opType,
            observed_at: normalizedObservedAt,
          }),
        ],
      );

      await this.db.query(
        `INSERT INTO ingestion_metrics (source_id, event_type, op_type, latency_ms, city_code)
         VALUES ($1, $2, $3, $4, $5)`,
        [source_id, normalizedType, opType, performance.now() - start, 'DEL'],
      );

      const duration = (performance.now() - start).toFixed(2);
      this.logger.log(
        `[INGEST] status=SUCCESS op=${opType} event_id=${eventId} source=${source_id} latency_ms=${duration} log_id=${ingestLogId}`,
      );

      return {
        status: 'SUCCESS',
        eventId,
        opType,
        logId: ingestLogId,
        idempotencyKey,
      };
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.error(`[INGEST] status=FAILED source=${source_id} reason=${message}`);
      await this.db.query(
        `INSERT INTO events_log (log_type, source, source_ref, idempotency_key, payload, error_message)
         VALUES ('FAILED', $1, $2, $3, $4, $5)`,
        [
          'TWITTER',
          source_id,
          idempotencyKey,
          JSON.stringify(event),
          message,
        ],
      );
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

  private makeIdempotencyKey(event: RawEvent): string {
    return createHash('sha256')
      .update(
        `${event.source_id}|${event.event_type}|${event.lat.toFixed(6)}|${event.lng.toFixed(6)}|${this.normalizeObservedAt(event.observed_at)}|${event.text ?? ''}`,
      )
      .digest('hex');
  }
}
