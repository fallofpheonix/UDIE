import { Injectable, Logger } from '@nestjs/common';
import * as h3 from 'h3-js';
import { WebSocket } from 'ws';
import { RiskSurfaceBounds, RiskSurfaceCacheService } from './risk-surface-cache.service';

export type RiskSurfaceStreamCell = {
  h3Index: string;
  riskWeight: number;
  eventCount: number;
  dominantHazard: string | null;
  hazardTypes: string[];
  boundary: Array<{ lat: number; lng: number }>;
};

export type RiskSurfaceStreamPayload = {
  updatedAt: string;
  bounds: RiskSurfaceBounds;
  cellCount: number;
  cells: RiskSurfaceStreamCell[];
};

type SubscriptionState = {
  bounds: RiskSurfaceBounds;
  limit: number;
};

@Injectable()
export class RiskStreamService {
  private readonly logger = new Logger(RiskStreamService.name);
  private readonly subscriptions = new Map<WebSocket, SubscriptionState>();
  private readonly defaultLimit = 256;

  constructor(private readonly riskSurfaceCache: RiskSurfaceCacheService) { }

  upsertSubscription(client: WebSocket, bounds: RiskSurfaceBounds, limit?: number) {
    this.subscriptions.set(client, {
      bounds,
      limit: this.normalizeLimit(limit),
    });
  }

  removeSubscription(client: WebSocket) {
    this.subscriptions.delete(client);
  }

  async syncClient(client: WebSocket) {
    const subscription = this.subscriptions.get(client);
    if (!subscription) {
      return;
    }
    const payload = this.buildPayload(subscription.bounds, subscription.limit);
    this.send(client, 'risk.surface.sync', payload);
  }

  async broadcastSurfaceRefresh() {
    if (this.subscriptions.size === 0) {
      return;
    }

    for (const [client, subscription] of this.subscriptions) {
      if (client.readyState !== WebSocket.OPEN) {
        this.subscriptions.delete(client);
        continue;
      }
      const payload = this.buildPayload(subscription.bounds, subscription.limit);
      this.send(client, 'risk.surface.update', payload);
    }

    this.logger.debug(`[RISK_STREAM] pushed_subscribers=${this.subscriptions.size}`);
  }

  private buildPayload(bounds: RiskSurfaceBounds, limit: number): RiskSurfaceStreamPayload {
    const cells = this.riskSurfaceCache.getCellsInBounds(bounds, limit);
    return {
      updatedAt: this.riskSurfaceCache.getUpdatedAt() ?? new Date().toISOString(),
      bounds,
      cellCount: cells.length,
      cells: cells.map((cell) => ({
        h3Index: cell.h3Index,
        riskWeight: Number(cell.weight.toFixed(6)),
        eventCount: cell.summary?.eventCount ?? 0,
        dominantHazard: cell.summary?.dominantHazard ?? null,
        hazardTypes: cell.summary?.hazardTypes ?? [],
        boundary: h3.cellToBoundary(cell.h3Index).map(([lat, lng]) => ({ lat, lng })),
      })),
    };
  }

  private normalizeLimit(limit?: number): number {
    if (!Number.isFinite(limit)) {
      return this.defaultLimit;
    }
    return Math.min(512, Math.max(32, Math.round(limit!)));
  }

  private send(client: WebSocket, event: string, data: unknown) {
    try {
      client.send(JSON.stringify({ event, data }));
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[RISK_STREAM] send_failed=true reason=${message}`);
      this.subscriptions.delete(client);
      try {
        client.close();
      } catch {
        // Ignore secondary close failure.
      }
    }
  }
}
