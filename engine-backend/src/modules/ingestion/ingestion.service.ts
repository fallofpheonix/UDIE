import { Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import { PartitionManagementService } from '../database/partition-management.service';
import {
  SocialEventParserService,
  SocialPostInput,
} from './social-event-parser.service';
import { SignalCredibilityService } from './signal-credibility.service';
import { AdversarialProtectionService } from './adversarial-protection.service';
import { BloomDedupService } from './bloom-dedup.service';

type CanonicalSourceType =
  | 'IOT_SENSOR'
  | 'TRAFFIC_CAMERA'
  | 'MUNICIPAL_FEED'
  | 'SOCIAL_MEDIA'
  | 'USER_REPORT';

type EventsLogSource = 'GOV_PORTAL' | 'ADMIN' | 'CROWD' | 'NEWS';

interface NormalizedEvent {
  index: number;
  raw: RawEvent;
  normalizedEventType: string;
  normalizedSourceType: CanonicalSourceType;
  mappedSource: EventsLogSource;
  observedAt: string;
  h3Index: string;
  h3Parent: string;
  severity: number;
  confidence: number;
  reliabilityScore: number;
  signalWeight: number;
  idempotencyKey: string;
  payload: Record<string, unknown>;
}

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
  metadata?: Record<string, unknown>;
  transport?: 'REST' | 'WEBSOCKET' | 'SOCIAL_PARSER';
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
  private readonly indiaBounds = {
    minLat: 6,
    maxLat: 37.6,
    minLng: 68,
    maxLng: 97.5,
  };
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
    private readonly spatial: SpatialService,
    private readonly partitionManager: PartitionManagementService,
    private readonly credibility: SignalCredibilityService,
    private readonly adversarial: AdversarialProtectionService,
    private readonly bloomDedup: BloomDedupService,
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
      transport: 'SOCIAL_PARSER',
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
    const results: Array<IngestionResult | undefined> = new Array(events.length);
    const validEvents: NormalizedEvent[] = [];

    for (let index = 0; index < events.length; index += 1) {
      const event = events[index];
      const normalized = await this.normalizeEvent(event, index);
      if ('status' in normalized) {
        results[index] = normalized;
        continue;
      }
      validEvents.push(normalized);
    }

    if (validEvents.length > 0) {
      await this.db.withTransaction(async (client) => {
        for (const event of validEvents) {
          const logId = await this.appendToEventsLog(client, event);
          if (!logId) {
            this.bloomDedup.remember(event.idempotencyKey);
            results[event.index] = {
              status: 'DUPLICATE',
              reason: 'IDEMPOTENT_REPLAY',
              idempotencyKey: event.idempotencyKey,
            };
            continue;
          }

          await this.appendRegionalProjection(client, logId, event);
          this.bloomDedup.remember(event.idempotencyKey);
          results[event.index] = {
            status: 'SUCCESS',
            logId,
            eventId: logId,
            idempotencyKey: event.idempotencyKey,
          };
        }
      });
    }

    const durationMs = Number((performance.now() - start).toFixed(2));
    this.logger.log(`[INGEST] batch=${events.length} accepted=${validEvents.length} duration_ms=${durationMs}`);
    return results.map((result) => result ?? { status: 'FAILED', reason: 'UNKNOWN_INGESTION_STATE' });
  }

  async processRawEvent(event: RawEvent): Promise<IngestionResult> {
    const results = await this.processRawEvents([event]);
    return results[0];
  }

  private async normalizeEvent(event: RawEvent, index: number): Promise<NormalizedEvent | IngestionResult> {
    const sourceId = event.source_id?.trim();
    if (!sourceId) {
      return { status: 'REJECTED', reason: 'INVALID_SOURCE_ID' };
    }

    if (!this.isWithinNationwideBounds(event.lat, event.lng)) {
      return { status: 'REJECTED', reason: 'OUT_OF_BOUNDS' };
    }

    const normalizedEventType = event.event_type?.toUpperCase().trim();
    if (!this.allowedEventTypes.has(normalizedEventType)) {
      return { status: 'REJECTED', reason: 'UNSUPPORTED_EVENT_TYPE' };
    }

    const sourceResolution = this.resolveSourceCategory(event.source_type);
    if (!sourceResolution) {
      return { status: 'REJECTED', reason: 'UNSUPPORTED_SOURCE_CATEGORY' };
    }

    const h3Parent = this.spatial.getRegionId(event.lat, event.lng);
    const h3Index = this.spatial.getH3Index(event.lat, event.lng);
    await this.partitionManager.ensurePartition(h3Parent);

    const protection = await this.adversarial.isAdversarial(sourceId, h3Index);
    if (protection.blocked) {
      return { status: 'REJECTED', reason: protection.reason ?? 'ADVERSARIAL_SIGNAL' };
    }

    const sourceCredibility = await this.credibility.calculateScore(sourceId, sourceResolution.sourceType);
    if (sourceCredibility < 0.2) {
      return { status: 'REJECTED', reason: 'LOW_CREDIBILITY' };
    }

    const severity = this.clampSeverity(event.severity_hint);
    const confidence = this.clampConfidence(
      event.confidence_hint,
      sourceResolution.sourceType === 'USER_REPORT' || sourceResolution.sourceType === 'SOCIAL_MEDIA' ? 0.72 : 0.92,
    );
    const reliabilityScore = this.clampProbability(sourceCredibility * confidence);
    const observedAt = this.normalizeObservedAt(event.observed_at);
    const idempotencyObservedAt = this.resolveIdempotencyTimestamp(event.observed_at);
    const idempotencyKey = this.makeIdempotencyKey(
      {
        ...event,
        source_id: sourceId,
        source_type: sourceResolution.sourceType,
        event_type: normalizedEventType,
        severity_hint: severity,
        confidence_hint: confidence,
        observed_at: idempotencyObservedAt,
      },
      h3Parent,
    );

    const probableDuplicate = await this.bloomDedup.isProbableDuplicate(
      idempotencyKey,
      async () => this.hasExistingIdempotencyKey(idempotencyKey),
    );
    if (probableDuplicate) {
      return {
        status: 'DUPLICATE',
        reason: 'BLOOM_SUPPRESSED_DUPLICATE',
        idempotencyKey,
      };
    }

    const signalWeight = Number((severity * reliabilityScore).toFixed(4));
    const h3IndexDb = this.spatial.toDbIndex(h3Index);
    const payload = {
      source_id: sourceId,
      source_type: sourceResolution.sourceType,
      original_source_category: event.source_type,
      mapped_source: sourceResolution.logSource,
      event_type: normalizedEventType,
      severity_hint: severity,
      confidence_hint: confidence,
      reliability_score: reliabilityScore,
      signal_weight: signalWeight,
      observed_at: observedAt,
      lat: event.lat,
      lng: event.lng,
      h3_index: h3IndexDb,
      h3_cell: h3Index,
      h3_parent: h3Parent,
      text: event.text ?? '',
      metadata: event.metadata ?? {},
      transport: event.transport ?? 'REST',
    };

    return {
      index,
      raw: event,
      normalizedEventType,
      normalizedSourceType: sourceResolution.sourceType,
      mappedSource: sourceResolution.logSource,
      observedAt,
      h3Index,
      h3Parent,
      severity,
      confidence,
      reliabilityScore,
      signalWeight,
      idempotencyKey,
      payload,
    };
  }

  private async appendToEventsLog(client: PoolClient, event: NormalizedEvent): Promise<string | null> {
    try {
      const result = await client.query<{ id: string }>(
        `INSERT INTO events_log (
           id,
           log_type,
           source,
           source_ref,
           idempotency_key,
           payload,
           ingested_at
         )
         VALUES (
           gen_random_uuid(),
           'INGESTED',
           $1::source_type_enum,
           $2,
           $3,
           $4::jsonb,
           now()
         )
         RETURNING id`,
        [
          event.mappedSource,
          event.raw.source_id.trim(),
          event.idempotencyKey,
          JSON.stringify(event.payload),
        ],
      );
      return result.rows[0]?.id ?? null;
    } catch (error: unknown) {
      if (this.isUniqueViolation(error)) {
        return null;
      }
      throw error;
    }
  }

  private async appendRegionalProjection(client: PoolClient, logId: string, event: NormalizedEvent): Promise<void> {
    await client.query(
      `INSERT INTO regional_events_log (
         id,
         h3_parent,
         log_type,
         source,
         source_ref,
         source_type,
         payload,
         reliability_score
       )
       VALUES (
         $1::uuid,
         $2::bigint,
         'INGESTED',
         $3,
         $4,
         $5,
         $6::jsonb,
         $7
       )
       ON CONFLICT (id, h3_parent) DO NOTHING`,
      [
        logId,
        event.h3Parent,
        event.raw.transport ?? 'REST',
        event.raw.source_id.trim(),
        event.normalizedSourceType,
        JSON.stringify(event.payload),
        event.reliabilityScore,
      ],
    );
  }

  private async hasExistingIdempotencyKey(idempotencyKey: string): Promise<boolean> {
    const result = await this.db.query<{ exists: boolean }>(
      `SELECT EXISTS(
         SELECT 1
         FROM events_log
         WHERE log_type = 'INGESTED'
           AND idempotency_key = $1
       ) AS exists`,
      [idempotencyKey],
    );
    return Boolean(result.rows[0]?.exists);
  }

  private resolveSourceCategory(rawSourceType?: string): { sourceType: CanonicalSourceType; logSource: EventsLogSource } | null {
    const normalized = rawSourceType?.toUpperCase().trim();
    switch (normalized) {
      case 'TRAFFIC_SENSOR':
      case 'TRAFFIC_SENSORS':
      case 'SENSOR':
      case 'IOT_SENSOR':
        return { sourceType: 'IOT_SENSOR', logSource: 'GOV_PORTAL' };
      case 'TRAFFIC_CAMERA':
      case 'CAMERA':
        return { sourceType: 'TRAFFIC_CAMERA', logSource: 'GOV_PORTAL' };
      case 'ROAD_CONSTRUCTION':
      case 'CONSTRUCTION':
      case 'ROADWORK':
      case 'CONSTRUCTION_FEED':
      case 'INFRASTRUCTURE_FEED':
      case 'MUNICIPAL_FEED':
        return { sourceType: 'MUNICIPAL_FEED', logSource: 'GOV_PORTAL' };
      case 'POLICE':
      case 'POLICE_ALERT':
      case 'LAW_ENFORCEMENT':
        return { sourceType: 'MUNICIPAL_FEED', logSource: 'ADMIN' };
      case 'SOCIAL':
      case 'SOCIAL_MEDIA':
        return { sourceType: 'SOCIAL_MEDIA', logSource: 'NEWS' };
      case 'USER':
      case 'CROWD':
      case 'USER_REPORT':
      case 'MANUAL_USER_REPORT':
        return { sourceType: 'USER_REPORT', logSource: 'CROWD' };
      default:
        return null;
    }
  }

  private isWithinNationwideBounds(lat: number, lng: number): boolean {
    return Number.isFinite(lat)
      && Number.isFinite(lng)
      && lat >= this.indiaBounds.minLat
      && lat <= this.indiaBounds.maxLat
      && lng >= this.indiaBounds.minLng
      && lng <= this.indiaBounds.maxLng;
  }

  private clampSeverity(value?: number): number {
    const numeric = Number(value ?? 3);
    if (!Number.isFinite(numeric)) {
      return 3;
    }
    return Math.max(1, Math.min(5, Math.round(numeric)));
  }

  private clampConfidence(value: number | undefined, fallback: number): number {
    const numeric = Number(value ?? fallback);
    if (!Number.isFinite(numeric)) {
      return fallback;
    }
    return this.clampProbability(numeric);
  }

  private clampProbability(value: number): number {
    return Number(Math.max(0.05, Math.min(1, value)).toFixed(4));
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
        `${regionId}|${event.source_id}|${event.event_type}|${event.lat.toFixed(6)}|${event.lng.toFixed(6)}|${this.resolveIdempotencyTimestamp(event.observed_at)}|${event.text ?? ''}`,
      )
      .digest('hex');
  }

  private resolveIdempotencyTimestamp(value?: string): string {
    if (value) {
      return this.normalizeObservedAt(value);
    }
    const bucketMs = 5 * 60_000;
    const bucketedNow = Math.floor(Date.now() / bucketMs) * bucketMs;
    return new Date(bucketedNow).toISOString();
  }

  private isUniqueViolation(error: unknown): boolean {
    return typeof error === 'object'
      && error !== null
      && 'code' in error
      && error.code === '23505';
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
}
