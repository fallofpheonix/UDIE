import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { DatabaseService } from '../../database/database.service';
import { PerformanceSentinel } from './performance-sentinel.service';

@Injectable()
export class PerformanceSentinelWorker {
  private readonly logger = new Logger(PerformanceSentinelWorker.name);

  constructor(
    private readonly sentinel: PerformanceSentinel,
    private readonly db: DatabaseService,
  ) {}

  @Cron('0 */15 * * * *')
  async run(): Promise<void> {
    try {
      const perf = await this.sentinel.collectSnapshot();
      await this.db.query('SELECT set_system_state($1, $2::jsonb)', [
        'performance_sentinel',
        JSON.stringify({ ...perf, generatedAt: new Date().toISOString() }),
      ]);
      this.logger.log(`[PERF_SENTINEL] healthy=${perf.healthy} latency_ms=${perf.riskLatencyAvgMs.toFixed(3)}`);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.error(`[PERF_SENTINEL] failed error=${message}`);
    }
  }
}
