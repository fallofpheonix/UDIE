import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

export interface DisruptionIdentity {
    id: string;
    eventType: string;
    h3Index: string;
    h3Parent: string;
    firstObservedAt: Date;
    lastObservedAt: Date;
    cumulativeSeverity: number;
    observationCount: number;
}

@Injectable()
export class DisruptionIdentityService implements OnModuleInit {
    private readonly logger = new Logger(DisruptionIdentityService.name);

    constructor(private readonly db: DatabaseService) { }

    async onModuleInit() {
        await this.ensureIdentitySchema();
    }

    private async ensureIdentitySchema() {
        await this.db.query(`
      CREATE TABLE IF NOT EXISTS disruption_identities (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        h3_index BIGINT NOT NULL,
        h3_parent BIGINT NOT NULL,
        event_type TEXT NOT NULL,
        cumulative_severity DOUBLE PRECISION NOT NULL DEFAULT 0,
        observation_count INT NOT NULL DEFAULT 0,
        first_observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        last_observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        is_active BOOLEAN NOT NULL DEFAULT true
      )
    `);

        await this.db.query(`
      CREATE TABLE IF NOT EXISTS log_to_identity_map (
        log_id UUID NOT NULL,
        h3_parent BIGINT NOT NULL,
        identity_id UUID NOT NULL,
        PRIMARY KEY (log_id, h3_parent, identity_id)
      )
    `);
    }

    /**
     * Links a log entry to a persistent disruption identity.
     * Logic: Finds an active identity of the same type in the same cell (or neighbors) 
     * within a reasonable time window.
     */
    async linkLogToIdentity(
        logId: string,
        h3Index: string,
        h3Parent: string,
        eventType: string,
        severity: number
    ): Promise<string> {
        // 1. Check for existing active identity in the same cell
        // Law: Identity is spatially anchored to its primary hex.
        const existing = await this.db.query(`
      SELECT id 
      FROM disruption_identities 
      WHERE h3_index = $1::bigint 
        AND event_type = $2 
        AND is_active = true 
        AND h3_parent = $3::bigint
        AND last_observed_at >= now() - interval '6 hours'
      LIMIT 1
    `, [h3Index, eventType, h3Parent]);

        if (existing.rows.length > 0) {
            const identityId = existing.rows[0].id;

            // Update existing identity
            await this.db.query(`
        UPDATE disruption_identities 
        SET 
          last_observed_at = now(),
          cumulative_severity = cumulative_severity + $1,
          observation_count = observation_count + 1
        WHERE id = $2 AND h3_parent = $3::bigint
      `, [severity, identityId, h3Parent]);

            await this.mapLogToIdentity(logId, h3Parent, identityId);
            return identityId;
        }

        // 2. Create new identity if no match found
        const newIdResult = await this.db.query(`
      INSERT INTO disruption_identities (h3_index, h3_parent, event_type, cumulative_severity, observation_count)
      VALUES ($1::bigint, $2::bigint, $3, $4, 1)
      RETURNING id
    `, [h3Index, h3Parent, eventType, severity]);

        const newId = newIdResult.rows[0].id;
        await this.mapLogToIdentity(logId, h3Parent, newId);

        this.logger.debug(`[IDENTITY] Created new identity ${newId} for ${eventType} at ${h3Index}`);
        return newId;
    }

    private async mapLogToIdentity(logId: string, h3Parent: string, identityId: string) {
        await this.db.query(`
      INSERT INTO log_to_identity_map (log_id, h3_parent, identity_id)
      VALUES ($1, $2::bigint, $3)
      ON CONFLICT DO NOTHING
    `, [logId, h3Parent, identityId]);
    }

    async deactivateStaleIdentities() {
        await this.db.query(`
      UPDATE disruption_identities 
      SET is_active = false 
      WHERE is_active = true 
        AND last_observed_at < now() - interval '24 hours'
    `);
    }
}
