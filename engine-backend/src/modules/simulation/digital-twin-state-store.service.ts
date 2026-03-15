import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { createClient, RedisClientType } from 'redis';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import { TwinCellState } from './digital-twin.types';

type TwinStateRow = QueryResultRow & {
  cell_id: string;
  region_id: string;
  traffic_density: number;
  average_speed: number;
  disruption_weight: number;
  risk_score: number;
  vehicle_count: number;
  timestamp: Date | string | null;
};

@Injectable()
export class DigitalTwinStateStoreService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DigitalTwinStateStoreService.name);
  private readonly states = new Map<string, TwinCellState>();
  private redis: RedisClientType | null = null;
  private redisReady = false;

  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService,
  ) {}

  async onModuleInit() {
    await this.connectRedis();
    await this.hydrate();
  }

  async onModuleDestroy() {
    if (this.redis) {
      await this.redis.quit().catch(() => undefined);
    }
  }

  async hydrate() {
    try {
      const result = await this.db.queryRead<TwinStateRow>(
        `
          SELECT
            (cell_id::h3index)::text AS cell_id,
            region_id::text AS region_id,
            traffic_density,
            average_speed,
            disruption_weight,
            risk_score,
            vehicle_count,
            timestamp
          FROM digital_twin_cell_states
          WHERE timestamp >= now() - interval '24 hours'
        `,
      );

      const next = result.rows.map((row) => this.mapRow(row));
      await this.replaceMany(next);
      this.logger.log(`[TWIN_STORE] hydrated_cells=${next.length}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[TWIN_STORE] hydrate_failed=${message}`);
    }
  }

  async replaceMany(states: TwinCellState[]) {
    this.states.clear();
    for (const state of states) {
      this.states.set(state.cellId, state);
    }

    if (!this.redis || !this.redisReady) {
      return;
    }

    const grouped = this.groupByRegion(states);
    const previousRegions = await this.redis.sMembers(this.regionsKey()).catch(() => []);
    const pipeline = this.redis.multi();
    for (const region of previousRegions) {
      pipeline.del(this.stateKey(region));
    }
    pipeline.del(this.regionsKey());

    for (const [regionId, record] of grouped) {
      pipeline.hSet(this.stateKey(regionId), record);
      pipeline.expire(this.stateKey(regionId), 900);
      pipeline.sAdd(this.regionsKey(), regionId);
    }

    await pipeline.exec();
  }

  async upsert(state: TwinCellState) {
    await this.upsertMany([state]);
  }

  async upsertMany(states: TwinCellState[]) {
    if (states.length === 0) {
      return;
    }

    for (const state of states) {
      this.states.set(state.cellId, state);
    }

    if (!this.redis || !this.redisReady) {
      return;
    }

    const grouped = this.groupByRegion(states);
    const pipeline = this.redis.multi();
    for (const [regionId, record] of grouped) {
      pipeline.hSet(this.stateKey(regionId), record);
      pipeline.expire(this.stateKey(regionId), 900);
      pipeline.sAdd(this.regionsKey(), regionId);
    }
    await pipeline.exec();
  }

  async getCells(cells: string[]): Promise<Map<string, TwinCellState>> {
    if (cells.length === 0) {
      return new Map();
    }

    if (!this.redis || !this.redisReady) {
      return this.getCellsFromMemory(cells);
    }

    try {
      const grouped = new Map<string, string[]>();
      for (const cell of cells) {
        const regionId = this.spatial.toDbIndex(this.spatial.getCellParent(cell));
        const bucket = grouped.get(regionId) ?? [];
        bucket.push(cell);
        grouped.set(regionId, bucket);
      }

      const regions = Array.from(grouped.entries());
      const pipeline = this.redis.multi();
      for (const [regionId, regionCells] of regions) {
        pipeline.hmGet(this.stateKey(regionId), regionCells);
      }

      const results = await pipeline.exec();
      if (!results) {
        return this.getCellsFromMemory(cells);
      }

      const mapped = new Map<string, TwinCellState>();
      let offset = 0;
      for (const [, regionCells] of regions) {
        const values = (results[offset++] ?? []) as Array<string | null>;
        for (let index = 0; index < regionCells.length; index += 1) {
          const payload = values[index];
          if (!payload) {
            continue;
          }
          const parsed = this.parseState(payload);
          if (parsed) {
            mapped.set(parsed.cellId, parsed);
          }
        }
      }

      return mapped;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[TWIN_STORE] redis_read_fallback=${message}`);
      this.redisReady = false;
      return this.getCellsFromMemory(cells);
    }
  }

  getState(cellId: string): TwinCellState | null {
    return this.states.get(cellId) ?? null;
  }

  size(): number {
    return this.states.size;
  }

  private async connectRedis() {
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
        this.logger.warn(`[TWIN_STORE] redis_error=${error.message}`);
      });
      await this.redis.connect();
      this.redisReady = true;
      this.logger.log('[TWIN_STORE] redis_status=connected');
    } catch (error) {
      this.redisReady = false;
      this.redis = null;
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[TWIN_STORE] redis_status=unavailable reason=${message}`);
    }
  }

  private groupByRegion(states: TwinCellState[]): Map<string, Record<string, string>> {
    const grouped = new Map<string, Record<string, string>>();
    for (const state of states) {
      const bucket = grouped.get(state.regionId) ?? {};
      bucket[state.cellId] = JSON.stringify(state);
      grouped.set(state.regionId, bucket);
    }
    return grouped;
  }

  private getCellsFromMemory(cells: string[]): Map<string, TwinCellState> {
    const mapped = new Map<string, TwinCellState>();
    for (const cell of cells) {
      const state = this.states.get(cell);
      if (state) {
        mapped.set(cell, state);
      }
    }
    return mapped;
  }

  private mapRow(row: TwinStateRow): TwinCellState {
    return {
      cellId: row.cell_id,
      regionId: row.region_id,
      trafficDensity: Number(row.traffic_density ?? 0),
      averageSpeed: Number(row.average_speed ?? 0),
      disruptionWeight: Number(row.disruption_weight ?? 0),
      riskScore: Number(row.risk_score ?? 0),
      vehicleCount: Number(row.vehicle_count ?? 0),
      timestamp: row.timestamp ? new Date(row.timestamp).toISOString() : null,
    };
  }

  private parseState(payload: string): TwinCellState | null {
    try {
      const parsed = JSON.parse(payload) as TwinCellState;
      if (!parsed?.cellId) {
        return null;
      }
      return parsed;
    } catch {
      return null;
    }
  }

  private stateKey(regionId: string): string {
    return `digital_twin:state:${regionId}`;
  }

  private regionsKey(): string {
    return 'digital_twin:regions';
  }
}
