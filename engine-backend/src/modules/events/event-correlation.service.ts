import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

export interface CorrelationResult {
    effectType: string;
    boostWeight: number;
}

@Injectable()
export class EventCorrelationService {
    private readonly logger = new Logger(EventCorrelationService.name);
    private correlations = new Map<string, CorrelationResult[]>();

    constructor(private readonly db: DatabaseService) { }

    async onModuleInit() {
        await this.loadCorrelations();
    }

    /**
     * Loads causal relationships from the database.
     * Example: CONSTRUCTION -> TRAFFIC (0.7 boost)
     */
    async loadCorrelations() {
        await this.db.query(`
      CREATE TABLE IF NOT EXISTS event_correlations (
        cause_type TEXT NOT NULL,
        effect_type TEXT NOT NULL,
        correlation_weight DOUBLE PRECISION NOT NULL CHECK (correlation_weight BETWEEN 0 AND 1),
        PRIMARY KEY (cause_type, effect_type)
      )
    `);

        await this.db.query(`
      INSERT INTO event_correlations (cause_type, effect_type, correlation_weight)
      VALUES
        ('CONSTRUCTION', 'HEAVY_TRAFFIC', 0.7),
        ('ACCIDENT', 'HEAVY_TRAFFIC', 0.6),
        ('PROTEST', 'ROAD_BLOCK', 0.8)
      ON CONFLICT (cause_type, effect_type) DO NOTHING
    `);

        const result = await this.db.query(`
      SELECT cause_type, effect_type, correlation_weight
      FROM event_correlations
    `);

        result.rows.forEach(row => {
            const list = this.correlations.get(String(row.cause_type)) || [];
            list.push({
                effectType: String(row.effect_type),
                boostWeight: Number(row.correlation_weight)
            });
            this.correlations.set(String(row.cause_type), list);
        });

        this.logger.log(`[CORRELATION] Loaded ${result.rows.length} causal relationships.`);
    }

    /**
     * Returns potential effects given a cause.
     * Enables the system to look for secondary disruptions.
     */
    getPotentialEffects(causeType: string): CorrelationResult[] {
        return this.correlations.get(causeType) || [];
    }
}
