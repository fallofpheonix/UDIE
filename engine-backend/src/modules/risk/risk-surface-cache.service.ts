import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import * as h3 from 'h3-js';
import { createClient, RedisClientType } from 'redis';
import { SpatialService } from '../common/spatial.service';

export type CellRiskSummary = {
  eventCount: number;
  hazardTypes: string[];
  dominantHazard: string | null;
};

export type CachedCellRisk = {
  weight: number;
  summary: CellRiskSummary | null;
};

export type RiskSurfaceBounds = {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
};

export type RiskSurfaceCell = {
  h3Index: string;
  weight: number;
  summary: CellRiskSummary | null;
};

@Injectable()
export class RiskSurfaceCacheService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RiskSurfaceCacheService.name);
  private readonly weights = new Map<string, number>();
  private readonly summaries = new Map<string, CellRiskSummary>();
  private lastUpdatedAt: string | null = null;
  private redis: RedisClientType | null = null;
  private redisReady = false;

  constructor(private readonly spatial: SpatialService) { }

  async onModuleInit() {
    const redisUrl = process.env.REDIS_URL?.trim();
    if (!redisUrl) {
      return;
    }

    try {
      this.redis = createClient({
        url: redisUrl,
        socket: {
          reconnectStrategy: false,
          connectTimeout: 500,
        },
      });
      this.redis.on('error', (error) => {
        this.redisReady = false;
        this.logger.warn(`[CACHE] redis_error=${error.message}`);
      });
      await this.redis.connect();
      this.redisReady = true;
      this.logger.log('[CACHE] redis_status=connected');
    } catch (error: unknown) {
      this.redisReady = false;
      this.redis = null;
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[CACHE] redis_status=unavailable reason=${message}`);
    }
  }

  async onModuleDestroy() {
    if (this.redis) {
      await this.redis.quit().catch(() => undefined);
    }
  }

  async replaceSurface(weights: Map<string, number>, summaries: Map<string, CellRiskSummary>) {
    this.weights.clear();
    this.summaries.clear();
    this.lastUpdatedAt = new Date().toISOString();

    for (const [cell, weight] of weights) {
      this.weights.set(cell, weight);
    }
    for (const [cell, summary] of summaries) {
      this.summaries.set(cell, summary);
    }

    if (!this.redis || !this.redisReady) {
      return;
    }

    const regionWeights = new Map<string, Record<string, string>>();
    const regionSummaries = new Map<string, Record<string, string>>();
    for (const [cell, weight] of weights) {
      const regionId = this.regionKey(cell);
      const weightRecord = regionWeights.get(regionId) ?? {};
      weightRecord[cell] = weight.toString();
      regionWeights.set(regionId, weightRecord);

      const summary = summaries.get(cell);
      if (summary) {
        const summaryRecord = regionSummaries.get(regionId) ?? {};
        summaryRecord[cell] = JSON.stringify(summary);
        regionSummaries.set(regionId, summaryRecord);
      }
    }

    const previousRegions = await this.redis.sMembers(this.regionsKey()).catch(() => []);
    const pipeline = this.redis.multi();
    for (const region of previousRegions) {
      pipeline.del(this.weightsKey(region));
      pipeline.del(this.summaryKey(region));
    }
    pipeline.del(this.regionsKey());

    for (const [regionId, record] of regionWeights) {
      pipeline.hSet(this.weightsKey(regionId), record);
      pipeline.expire(this.weightsKey(regionId), 600);
      pipeline.sAdd(this.regionsKey(), regionId);
      const summaryRecord = regionSummaries.get(regionId);
      if (summaryRecord && Object.keys(summaryRecord).length > 0) {
        pipeline.hSet(this.summaryKey(regionId), summaryRecord);
        pipeline.expire(this.summaryKey(regionId), 600);
      }
    }
    pipeline.set(this.updatedAtKey(), this.lastUpdatedAt, { EX: 600 });
    await pipeline.exec();
  }

  async seedWeights(weights: Map<string, number>) {
    this.weights.clear();
    if (!this.lastUpdatedAt) {
      this.lastUpdatedAt = new Date().toISOString();
    }
    for (const [cell, weight] of weights) {
      this.weights.set(cell, weight);
    }
  }

  async getCells(cells: string[]): Promise<Map<string, CachedCellRisk>> {
    if (cells.length === 0) {
      return new Map();
    }

    if (!this.redis || !this.redisReady) {
      return this.getCellsFromMemory(cells);
    }

    try {
      const grouped = this.groupCellsByRegion(cells);
      const pipeline = this.redis.multi();
      const orderedRegions: Array<{ regionId: string; cells: string[] }> = [];
      for (const [regionId, regionCells] of grouped) {
        orderedRegions.push({ regionId, cells: regionCells });
        pipeline.hmGet(this.weightsKey(regionId), regionCells);
        pipeline.hmGet(this.summaryKey(regionId), regionCells);
      }
      const redisResults = await pipeline.exec();
      if (!redisResults) {
        return this.getCellsFromMemory(cells);
      }

      const values = new Map<string, CachedCellRisk>();
      let offset = 0;
      for (const region of orderedRegions) {
        const weightValues = (redisResults[offset++] ?? []) as Array<string | null>;
        const summaryValues = (redisResults[offset++] ?? []) as Array<string | null>;
        for (let index = 0; index < region.cells.length; index += 1) {
          const cell = region.cells[index];
          const weight = Number(weightValues[index] ?? 0);
          if (!Number.isFinite(weight) || weight <= 0) {
            continue;
          }
          const summary = this.parseSummary(summaryValues[index]);
          values.set(cell, {
            weight,
            summary,
          });
        }
      }
      return values;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[CACHE] redis_read_fallback=true reason=${message}`);
      this.redisReady = false;
      return this.getCellsFromMemory(cells);
    }
  }

  getWeight(cell: string): number {
    return this.weights.get(cell) ?? 0;
  }

  getSummary(cell: string): CellRiskSummary | null {
    return this.summaries.get(cell) ?? null;
  }

  getUpdatedAt(): string | null {
    return this.lastUpdatedAt;
  }

  isRedisReady(): boolean {
    return this.redisReady;
  }

  getCellsInBounds(bounds: RiskSurfaceBounds, limit = 256): RiskSurfaceCell[] {
    const values: RiskSurfaceCell[] = [];
    for (const [cell, weight] of this.weights) {
      if (weight <= 0) {
        continue;
      }
      const [lat, lng] = h3.cellToLatLng(cell);
      if (!this.isWithinBounds(lat, lng, bounds)) {
        continue;
      }
      values.push({
        h3Index: cell,
        weight,
        summary: this.summaries.get(cell) ?? null,
      });
    }

    values.sort((left, right) => right.weight - left.weight);
    return values.slice(0, Math.max(1, limit));
  }

  private getCellsFromMemory(cells: string[]): Map<string, CachedCellRisk> {
    const values = new Map<string, CachedCellRisk>();
    for (const cell of cells) {
      const weight = this.weights.get(cell) ?? 0;
      if (weight <= 0) {
        continue;
      }
      values.set(cell, {
        weight,
        summary: this.summaries.get(cell) ?? null,
      });
    }
    return values;
  }

  private groupCellsByRegion(cells: string[]): Map<string, string[]> {
    const grouped = new Map<string, string[]>();
    for (const cell of cells) {
      const regionId = this.regionKey(cell);
      const bucket = grouped.get(regionId) ?? [];
      bucket.push(cell);
      grouped.set(regionId, bucket);
    }
    return grouped;
  }

  private regionKey(cell: string): string {
    return this.spatial.toDbIndex(h3.cellToParent(cell, 6));
  }

  private weightsKey(regionId: string): string {
    return `risk_surface:weights:${regionId}`;
  }

  private summaryKey(regionId: string): string {
    return `risk_surface:summaries:${regionId}`;
  }

  private regionsKey(): string {
    return 'risk_surface:regions';
  }

  private updatedAtKey(): string {
    return 'risk_surface:updated_at';
  }

  private isWithinBounds(lat: number, lng: number, bounds: RiskSurfaceBounds): boolean {
    return lat >= bounds.minLat &&
      lat <= bounds.maxLat &&
      lng >= bounds.minLng &&
      lng <= bounds.maxLng;
  }

  private parseSummary(value: string | null): CellRiskSummary | null {
    if (!value) {
      return null;
    }
    try {
      return JSON.parse(value);
    } catch {
      return null;
    }
  }
}
