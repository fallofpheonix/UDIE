import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { createHash } from 'crypto';
import { createClient, RedisClientType } from 'redis';

@Injectable()
export class RouteCacheService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RouteCacheService.name);
  private readonly memory = new Map<string, { expiresAt: number; payload: unknown }>();
  private redis: RedisClientType | null = null;
  private redisReady = false;

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
        this.logger.warn(`[ROUTE_CACHE] redis_error=${error.message}`);
      });
      await this.redis.connect();
      this.redisReady = true;
    } catch (error: unknown) {
      this.redis = null;
      this.redisReady = false;
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[ROUTE_CACHE] redis_status=unavailable reason=${message}`);
    }
  }

  async onModuleDestroy() {
    if (this.redis) {
      await this.redis.quit().catch(() => undefined);
    }
  }

  buildKey(namespace: string, payload: Record<string, unknown>) {
    const encoded = JSON.stringify(payload, Object.keys(payload).sort());
    const digest = createHash('sha1').update(encoded).digest('hex');
    return `${namespace}:${digest}`;
  }

  async get<T>(key: string): Promise<T | null> {
    const current = this.memory.get(key);
    const now = Date.now();
    if (current && current.expiresAt > now) {
      return current.payload as T;
    }
    if (current) {
      this.memory.delete(key);
    }

    if (!this.redis || !this.redisReady) {
      return null;
    }

    try {
      const value = await this.redis.get(this.redisKey(key));
      if (!value) {
        return null;
      }
      return JSON.parse(value) as T;
    } catch (error: unknown) {
      this.redisReady = false;
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[ROUTE_CACHE] redis_read_fallback=true reason=${message}`);
      return null;
    }
  }

  async set(key: string, payload: unknown, ttlSeconds = 60) {
    const expiresAt = Date.now() + (ttlSeconds * 1000);
    this.memory.set(key, { expiresAt, payload });

    if (!this.redis || !this.redisReady) {
      return;
    }

    try {
      const redisKey = this.redisKey(key);
      await this.redis.set(redisKey, JSON.stringify(payload), { EX: ttlSeconds });
      await this.redis.sAdd(this.indexKey(), redisKey);
      await this.redis.expire(this.indexKey(), Math.max(ttlSeconds, 120));
    } catch (error: unknown) {
      this.redisReady = false;
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[ROUTE_CACHE] redis_write_fallback=true reason=${message}`);
    }
  }

  async invalidateAll() {
    this.memory.clear();
    if (!this.redis || !this.redisReady) {
      return;
    }

    try {
      const keys = await this.redis.sMembers(this.indexKey());
      if (keys.length > 0) {
        await this.redis.del(keys);
      }
      await this.redis.del(this.indexKey());
    } catch (error: unknown) {
      this.redisReady = false;
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[ROUTE_CACHE] redis_invalidate_fallback=true reason=${message}`);
    }
  }

  private redisKey(key: string) {
    return `route_cache:${key}`;
  }

  private indexKey() {
    return 'route_cache:index';
  }
}
