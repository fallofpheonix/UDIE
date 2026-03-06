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
}
