import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class AdversarialProtectionService {
    private readonly BURST_THRESHOLD = 10; // Max events per 10s window

    constructor(private readonly db: DatabaseService) { }

    /**
     * Detects if an incoming signal is part of an adversarial burst.
     * Checks both source-based and spatial-based volume.
     */
    async isAdversarial(sourceId: string, h3Index: string): Promise<{ blocked: boolean; reason?: string }> {
        // 1. Check Source Burst
        const sourceBurst = await this.db.query<{ count: number }>(
            `SELECT COUNT(*)::int as count 
       FROM events_log 
       WHERE log_type = 'INGESTED'
         AND source_ref = $1 
         AND ingested_at > now() - interval '10 seconds'`,
            [sourceId]
        );

        if (sourceBurst.rows[0]?.count > this.BURST_THRESHOLD) {
            return { blocked: true, reason: 'SOURCE_SIGNAL_FLOOD' };
        }

        // 2. Check Spatial Burst (H3 Res 9)
        const spatialBurst = await this.db.query<{ count: number }>(
            `SELECT COUNT(*)::int as count 
        FROM events_log 
        WHERE log_type = 'INGESTED'
          AND payload->>'h3_cell' = $1
          AND ingested_at > now() - interval '10 seconds'`,
            [h3Index]
        );

        if (spatialBurst.rows[0]?.count > this.BURST_THRESHOLD * 2) {
            return { blocked: true, reason: 'SPATIAL_SIGNAL_FLOOD' };
        }

        return { blocked: false };
    }
}
