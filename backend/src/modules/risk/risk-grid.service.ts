import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { ObservabilityService } from '../common/observability.service';

type RiskGridRow = QueryResultRow & { h3_index: string; weight: number };

/**
 * High-performance in-memory store for the nationwide risk surface.
 * Enables <1ms latency for /risk queries by bypassing the database.
 */
@Injectable()
export class RiskGridService implements OnModuleInit {
    private readonly logger = new Logger(RiskGridService.name);
    private riskGrid = new Map<string, number>();

    constructor(
      private readonly db: DatabaseService,
      private readonly observability: ObservabilityService,
    ) { }

    async onModuleInit() {
        await this.hydrate();
    }

    /**
     * Loads the latest risk weights from the versioned database grid.
     */
    async hydrate() {
        const startedAt = Date.now();
        this.logger.log('[IN-MEM] Hydrating risk grid from database...');
        try {
            // Read from pre-aggregated risk_cells only (hot-path source of truth).
            const result = await this.db.query<RiskGridRow>(`
        SELECT
          (h3_index::h3index)::text AS h3_index,
          weight 
        FROM risk_cells
      `);

            result.rows.forEach((row: RiskGridRow) => {
                this.riskGrid.set(row.h3_index, Number(row.weight));
            });

            this.observability.setRiskGridSize(this.riskGrid.size);
            this.observability.observeRiskGridRefreshTime((Date.now() - startedAt) / 1000);
            this.logger.log(`[IN-MEM] Hydration complete. Managed cells: ${this.riskGrid.size}`);
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : 'unknown';
            this.logger.warn(`[IN-MEM] Hydration skipped or failed: ${message}. Grid starts empty.`);
        }
    }

    getWeight(h3Index: string): number {
        return this.riskGrid.get(h3Index) ?? 0;
    }

    upsertWeight(h3Index: string, weight: number) {
        this.riskGrid.set(h3Index, Math.max(0, weight));
    }

    /**
     * Incremental update for streaming aggregation.
     */
    updateWeight(h3Index: string, delta: number) {
        const current = this.getWeight(h3Index);
        this.riskGrid.set(h3Index, Math.max(0, current + delta));
    }

    setWeight(h3Index: string, weight: number) {
        this.riskGrid.set(h3Index, Math.max(0, weight));
        this.observability.setRiskGridSize(this.riskGrid.size);
    }

    getAllActiveIndices(): string[] {
        return Array.from(this.riskGrid.keys());
    }

    size(): number {
      return this.riskGrid.size;
    }
}
