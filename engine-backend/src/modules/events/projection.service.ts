import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { Interval } from '@nestjs/schedule';
import { SpatialService } from '../common/spatial.service';
import { RiskGridService } from '../risk/risk-grid.service';
import { DisruptionIdentityService } from './disruption-identity.service';
import { EventCorrelationService } from './event-correlation.service';

@Injectable()
export class ProjectionService implements OnModuleInit {
    private readonly logger = new Logger(ProjectionService.name);
    private readonly batchSize = 100;

    constructor(
        private readonly db: DatabaseService,
        private readonly spatial: SpatialService,
        private readonly inMemRisk: RiskGridService,
        private readonly identityService: DisruptionIdentityService,
        private readonly correlationService: EventCorrelationService,
    ) {
        // Periodic recomputations removed in favor of real-time streaming (Phase 7).
    }

    onModuleInit() {
        this.logger.log('[PROJECTION] Orchestrator initialized.');
    }

    @Interval(5000)
    async handleProjection() {
        try {
            // 1. Find regions with unprocessed logs
            const regions = await this.db.query(`
        SELECT DISTINCT h3_parent 
        FROM regional_events_log 
        WHERE log_type = 'INGESTED'
        LIMIT 5
    `);

            for (const row of regions.rows) {
                await this.processRegion(row.h3_parent);
            }

            // Housekeeping
            await this.identityService.deactivateStaleIdentities();
        } catch (error: any) {
            this.logger.error(`[PROJECTION] Global loop failed: ${error.message}`);
        }
    }

    private async processRegion(h3Parent: string) {
        const start = performance.now();
        try {
            // Acquire regional lock
            const lockKey = parseInt(h3Parent.substring(0, 8), 16) || 41003;
            const locked = await this.db.query('SELECT pg_try_advisory_lock($1) AS ok', [lockKey]);
            if (!locked.rows[0]?.ok) return;

            // Fetch batch projected from the authoritative events_log append stream.
            const logs = await this.db.query(
                `SELECT l.id, l.payload, l.source_type, COALESCE(l.reliability_score, 0.7) AS reliability_score
         FROM regional_events_log l
         WHERE l.h3_parent = $1 AND l.log_type = 'INGESTED' 
         LIMIT $2`,
                [h3Parent, this.batchSize]
            );

            for (const log of logs.rows) {
                const event = JSON.parse(JSON.stringify(log.payload));
                const h3Cell = this.spatial.getH3Index(event.lat, event.lng);
                const h3Index = this.spatial.toDbIndex(h3Cell);
                const reliabilityScore = Math.max(0.05, Math.min(1, Number(log.reliability_score ?? event.reliability_score ?? event.confidence_hint ?? 0.7)));
                const rawSeverity = Math.max(1, Math.min(5, Number(event.severity_hint ?? 5)));
                const weightedSeverity = rawSeverity * reliabilityScore;

                // Law 11: Persistent Disruption Identities
                await this.identityService.linkLogToIdentity(
                    log.id,
                    h3Index,
                    h3Parent,
                    event.event_type,
                    weightedSeverity
                );

                // Law 5: Immutable Versioning
                await this.db.query(`
          INSERT INTO regional_geo_events_v(event_id, version, h3_parent, h3_index, event_type, severity, confidence, geom, observed_at)
VALUES($1, (SELECT COALESCE(MAX(version), 0) + 1 FROM regional_geo_events_v WHERE event_id = $1) + 1, $2::bigint, $3::bigint, $4, $5, $6, ST_SetSRID(ST_MakePoint($7, $8), 4326)::geography, $9)
`, [
                    log.id, h3Parent, h3Index, event.event_type,
                    rawSeverity, reliabilityScore, event.lng, event.lat,
                    event.observed_at || new Date().toISOString()
                ]);

                // Streaming Aggregation Update
                this.inMemRisk.updateWeight(h3Cell, weightedSeverity * 0.1);

                // Law 9: Causal Inference (Event Correlation)
                const correlations = this.correlationService.getPotentialEffects(event.event_type);
                for (const potential of correlations) {
                    // If we detect a cause (e.g. CONSTRUCTION), we boost the expectation of the effect (e.g. TRAFFIC)
                    // This implements Phase 9: Qualitative Signal Integrity
                    this.inMemRisk.updateWeight(h3Cell, weightedSeverity * potential.boostWeight * 0.05);
                }

                // Mark as PROCESSED
                await this.db.query(
                    `UPDATE regional_events_log SET log_type = 'PROCESSED' WHERE id = $1 AND h3_parent = $2`,
                    [log.id, h3Parent]
                );
            }

            const duration = (performance.now() - start).toFixed(2);
            if (logs.rows.length > 0) {
                this.logger.debug(`[PROJECTION] Region ${h3Parent} processed ${logs.rows.length} events in ${duration}ms`);
            }

            await this.db.query('SELECT pg_advisory_unlock($1)', [lockKey]);
        } catch (error: any) {
            this.logger.error(`[PROJECTION] Region ${h3Parent} failed: ${error.message}`);
        }
    }
}
