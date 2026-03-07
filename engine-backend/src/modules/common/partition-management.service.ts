import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class PartitionManagementService implements OnModuleInit {
    private readonly logger = new Logger(PartitionManagementService.name);
    private readonly knownPartitions = new Set<string>();

    constructor(private readonly db: DatabaseService) { }

    async onModuleInit() {
        await this.syncKnownPartitions();
    }

    /**
     * Synchronizes the in-memory cache of existing partitions from the DB.
     */
    async syncKnownPartitions() {
        try {
            const result = await this.db.query('SELECT h3_parent::text FROM spatial_regions');
            result.rows.forEach((row: any) => this.knownPartitions.add(row.h3_parent));
            this.logger.log(`[PARTITION] Synced ${this.knownPartitions.size} existing regions.`);
        } catch (error: any) {
            this.logger.error(`[PARTITION] Sync failed: ${error.message}`);
        }
    }

    /**
     * Ensures that partitions for a given H3 parent (Resolution 6) exist.
     * Law: New regions are handled automatically without manual schema updates.
     */
    async ensurePartition(h3Parent: string): Promise<void> {
        if (this.knownPartitions.has(h3Parent)) return;

        try {
            this.logger.log(`[PARTITION] Creating new spatial partition for region: ${h3Parent}`);
            // Function defined in Migration 024
            await this.db.query('SELECT create_spatial_partition($1::bigint)', [h3Parent]);
            this.knownPartitions.add(h3Parent);
        } catch (error: any) {
            this.logger.error(`[PARTITION] Failed to create partition ${h3Parent}: ${error.message}`);
            throw error;
        }
    }

    async createPartition(regionId: string): Promise<void> {
        await this.ensurePartition(regionId);
    }

    async rotatePartition(regionId: string): Promise<void> {
        await this.ensurePartition(regionId);
        await this.db.query(
            `UPDATE spatial_regions
             SET last_accessed_at = now(), updated_at = now()
             WHERE h3_parent = $1::bigint`,
            [regionId],
        );
    }

    async monitorRegionLoad(limit = 20): Promise<Array<{ regionId: string; eventsLastHour: number }>> {
        const result = await this.db.query(
            `SELECT h3_parent::text AS region_id, COUNT(*)::int AS events_last_hour
             FROM regional_events_log
             WHERE created_at >= now() - interval '1 hour'
             GROUP BY h3_parent
             ORDER BY events_last_hour DESC
             LIMIT $1`,
            [limit],
        );

        return result.rows.map((row: any) => ({
            regionId: String(row.region_id),
            eventsLastHour: Number(row.events_last_hour),
        }));
    }

    async detectHotRegion(thresholdPerHour: number): Promise<string[]> {
        const result = await this.db.query(
            `SELECT h3_parent::text AS region_id
             FROM regional_events_log
             WHERE created_at >= now() - interval '1 hour'
             GROUP BY h3_parent
             HAVING COUNT(*) >= $1`,
            [thresholdPerHour],
        );

        return result.rows.map((row: any) => String(row.region_id));
    }

    async splitRegionPartition(regionId: string): Promise<void> {
        // Foundation hook: currently records scaling intent and keeps deterministic routing stable.
        await this.db.query(
            `SELECT set_system_state($1, $2::jsonb)`,
            [
                `partition_split_request:${regionId}`,
                JSON.stringify({
                    regionId,
                    requested_at: new Date().toISOString(),
                    status: 'PENDING',
                    reason: 'hot_region_detected',
                }),
            ],
        );
    }

    async rebalanceWorkers(regionIds: string[]): Promise<void> {
        await this.db.query(
            `SELECT set_system_state($1, $2::jsonb)`,
            [
                'partition_rebalance',
                JSON.stringify({
                    region_ids: regionIds,
                    requested_at: new Date().toISOString(),
                    status: 'PENDING',
                }),
            ],
        );
    }
}
