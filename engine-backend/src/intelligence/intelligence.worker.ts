import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { IntelligenceService } from './IntelligenceService';
import { DatabaseService } from '../database/database.service';
import { AnomalyDetectionService } from './anomaly-detection.service';

@Injectable()
export class IntelligenceWorker {
  private readonly logger = new Logger(IntelligenceWorker.name);

  constructor(
    private readonly intelligenceService: IntelligenceService,
    private readonly anomalyDetectionService: AnomalyDetectionService,
    private readonly db: DatabaseService,
  ) { }

  @Cron('0 */2 * * * *')
  async run() {
    const start = performance.now();
    this.logger.log('[INTEL_WORKER] job_start=true');

    try {
      await this.anomalyDetectionService.detectSpikes();
      const created = await this.intelligenceService.runAnalysis();
      const duration = Number((performance.now() - start).toFixed(2));

      await this.db.query(`SELECT set_system_state($1, $2::jsonb)`, [
        'intelligence',
        JSON.stringify({
          status: 'OK',
          duration_ms: duration,
          insights_created: created,
          last_success_at: new Date().toISOString(),
        }),
      ]);

      this.logger.log(`[INTEL_WORKER] status=SUCCESS duration_ms=${duration} insights_created=${created}`);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';

      await this.db.query(`SELECT set_system_state($1, $2::jsonb)`, [
        'intelligence',
        JSON.stringify({
          status: 'FAILED',
          error: message,
          last_failure_at: new Date().toISOString(),
        }),
      ]);

      this.logger.error(`[INTEL_WORKER] status=FAILED error=${message}`);
    }
  }
}
