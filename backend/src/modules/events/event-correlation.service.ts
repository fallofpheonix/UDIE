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
