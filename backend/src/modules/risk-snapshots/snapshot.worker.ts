import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class SnapshotWorker {
  private readonly logger = new Logger(SnapshotWorker.name);

  constructor(private readonly db: DatabaseService) {}

  @Cron('0 */5 * * * *')
  async run(): Promise<void> {
    const started = performance.now();
    try {
      await this.db.query(`
        INSERT INTO risk_snapshots (snapshot_time, h3_index, risk_weight)
        SELECT date_trunc('minute', now()), h3_index, weight
        FROM risk_cells
      `);
      this.logger.log(`[SNAPSHOT] status=SUCCESS duration_ms=${(performance.now() - started).toFixed(2)}`);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.error(`[SNAPSHOT] status=FAILED error=${message}`);
    }
  }
}
