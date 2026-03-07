import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class SignalCredibilityService {
    private readonly logger = new Logger(SignalCredibilityService.name);

    constructor(private readonly db: DatabaseService) { }

    /**
     * Calculates a Bayesian credibility score for a signal source.
     * Score = (Prior Trust * Evidence) / Normalization
     */
    async calculateScore(sourceId: string, sourceType: string): Promise<number> {
        const sourceDef = await this.db.query<{ base_weight: number; is_official: boolean }>(
            'SELECT base_weight, is_official FROM source_definitions WHERE source_type = $1',
            [sourceType.toUpperCase()]
        );

        const baseWeight = sourceDef.rows[0]?.base_weight ?? 0.5;
        const isOfficial = sourceDef.rows[0]?.is_official ?? false;

        if (isOfficial) {
            return baseWeight; // Official sources have fixed high trust
        }

        // For social/user reports, check historical accuracy
        const history = await this.db.query<{ accuracy: number }>(
            `SELECT COALESCE(AVG(CASE WHEN status = 'RESOLVED' THEN 1.0 ELSE 0.5 END), 0.7) as accuracy
       FROM geo_events
       WHERE source_id = $1
       LIMIT 100`,
            [sourceId]
        );

        const accuracy = Number(history.rows[0]?.accuracy ?? 0.7);

        // Bayesian posterior: simplified for production
        // Posterior = (Accuracy * BaseWeight) / (Accuracy * BaseWeight + (1-Accuracy)*(1-BaseWeight))
        const posterior = (accuracy * baseWeight) / (accuracy * baseWeight + (1 - accuracy) * (1 - baseWeight));

        return parseFloat(posterior.toFixed(4));
    }
}
