import { Injectable, Logger } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { Cron, CronExpression } from '@nestjs/schedule';

type RegionRow = QueryResultRow & { h3_parent: string };

@Injectable()
export class PartitionManagementService {
    private readonly logger = new Logger(PartitionManagementService.name);
    private initializedRegions = new Set<string>();

    constructor(private readonly db: DatabaseService) { }

    /**
     * Ensures a regional partition exists for a given H3 Res 6 parent.
     * Uses a local cache to minimize DB overhead.
     */
    async ensurePartition(regionId: string): Promise<void> {
        if (this.initializedRegions.has(regionId)) {
            return;
        }

        try {
            // Check if region already initialized in DB
            const result = await this.db.query(
                'SELECT 1 FROM spatial_regions WHERE h3_parent = $1',
                [regionId],
            );

            if (result.rows.length === 0) {
                this.logger.log(`[PARTITION] Creating partition for region=${regionId}`);
                await this.db.query('SELECT create_spatial_partition($1)', [regionId]);
            }

            this.initializedRegions.add(regionId);
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : 'unknown';
            this.logger.error(
                `[PARTITION] Failed to ensure partition for region=${regionId}: ${message}`,
            );
            throw error;
        }
    }

    /**
     * Loads all active regions into the local cache.
     */
    async loadActiveRegions(): Promise<void> {
        const result = await this.db.query<RegionRow>(
            'SELECT h3_parent FROM spatial_regions WHERE is_active = true',
        );
        result.rows.forEach((row) => this.initializedRegions.add(row.h3_parent));
        this.logger.log(`[PARTITION] Loaded ${this.initializedRegions.size} active regions.`);
    }

    /**
     * Monitors signal density across all active Res 6 partitions.
     * Law 3 (Bounded Input) and Law 13 (Distributed Scaling).
     */
    @Cron(CronExpression.EVERY_HOUR)
    async monitorDensity(): Promise<void> {
        this.logger.log('[SCALING] Scanning partition densities...');
        const result = await this.db.query<QueryResultRow>(`
            SELECT h3_parent, COUNT(*)::int AS signal_count
            FROM regional_events_log
            WHERE log_type = 'INGESTED'
            GROUP BY h3_parent
        `);

        for (const row of result.rows) {
            const count = row.signal_count;
            const region = row.h3_parent;

            if (count > 10000) {
                this.logger.warn(`[SCALING] HOT REGION DETECTED: region=${region} density=${count}. Initiating Sub-Partitioning (Res 7)...`);
                await this.splitPartition(region);
            }
        }
    }

    private async splitPartition(regionId: string): Promise<void> {
        // Law 15: Sub-partitioning MUST be deterministic.
        // Implementation note: This would trigger a migration or a dynamic table creation loop.
        // For now, we log the intent and set a system state flag.
        await this.db.query(
            'SELECT set_system_state($1, $2::jsonb)',
            [`split_intent_${regionId}`, JSON.stringify({ target: 'RES_7', density_trigger: 10000, detected_at: new Date() })]
        );
    }
}
