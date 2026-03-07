import { Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { DatabaseService } from '../../database/database.service';
import { AIResolverService } from './ai-resolver.service';

export interface ErrorContext {
    service: string;
    component: string;
    type: string;
    message: string;
    severity: number;
    metadata?: Record<string, any>;
}

@Injectable()
export class ErrorLogService {
    private readonly logger = new Logger(ErrorLogService.name);

    constructor(
        private readonly db: DatabaseService,
        private readonly ai: AIResolverService
    ) { }

    /**
     * Logs a structured system error with fingerprinting and automated diagnostics.
     */
    async logSystemError(ctx: ErrorContext): Promise<void> {
        const fingerprint = this.computeErrorFingerprint(ctx.service, ctx.component, ctx.message);

        try {
            const existing = await this.db.query(
                'SELECT id FROM system_errors WHERE stack_hash = $1',
                [fingerprint]
            );

            if (existing.rowCount && existing.rowCount > 0) {
                await this.db.query(
                    `UPDATE system_errors 
           SET occurrence_count = occurrence_count + 1, 
               timestamp = now() 
           WHERE stack_hash = $1`,
                    [fingerprint]
                );
            } else {
                const probableCause = this.inferProbableCause(ctx.message);
                const aiSuggestion = await this.ai.analyzeError(ctx.message, ctx.component, ctx.type);

                await this.db.query(
                    `INSERT INTO system_errors (
            service, component, error_type, error_message, stack_hash, severity, probable_cause, ai_suggestion, metadata
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
                    [
                        ctx.service,
                        ctx.component,
                        ctx.type,
                        ctx.message,
                        fingerprint,
                        ctx.severity,
                        probableCause,
                        aiSuggestion,
                        JSON.stringify(ctx.metadata || {}),
                    ]
                );
            }
        } catch (error) {
            this.logger.error(`Failed to log system error: ${error instanceof Error ? error.message : 'unknown'}`);
        }
    }

    private computeErrorFingerprint(service: string, component: string, message: string): string {
        const normalized = message.replace(/\d+/g, 'N'); // Normalize numbers to deduplicate similar varied messages
        return createHash('sha256')
            .update(`${service}|${component}|${normalized}`)
            .digest('hex');
    }

    private inferProbableCause(message: string): string {
        const msg = message.toLowerCase();
        if (msg.includes('timeout')) return 'network_latency';
        if (msg.includes('connection refused') || msg.includes('econnrefused')) return 'database_unavailable';
        if (msg.includes('memory') || msg.includes('heap')) return 'memory_pressure';
        if (msg.includes('lock') || msg.includes('deadlock')) return 'database_lock_contention';
        if (msg.includes('seq scan')) return 'query_plan_regression';
        if (msg.includes('h3') || msg.includes('res 9')) return 'spatial_index_error';
        return 'unknown_logic_failure';
    }
}
