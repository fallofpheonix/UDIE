import { Injectable, Logger } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';

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
}
