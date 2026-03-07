import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { DatabaseService } from '../../database/database.service';
import { ArchitectureAuditService } from './architecture-audit.service';

@Injectable()
export class ArchitectureAuditWorker {
  private readonly logger = new Logger(ArchitectureAuditWorker.name);

  constructor(
    private readonly audit: ArchitectureAuditService,
    private readonly db: DatabaseService,
  ) {}

  @Cron('0 0 */6 * * *')
  async run(): Promise<void> {
    const start = performance.now();
    try {
      const report = await this.audit.runFullAudit();
      await this.db.query('SELECT set_system_state($1, $2::jsonb)', [
        'architecture_audit',
        JSON.stringify({
          ...report,
          durationMs: Number((performance.now() - start).toFixed(2)),
        }),
      ]);
      this.logger.log(`[ARCH_AUDIT] status=${report.status}`);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      await this.db.query('SELECT set_system_state($1, $2::jsonb)', [
        'architecture_audit',
        JSON.stringify({
          status: 'failed',
          error: message,
          generatedAt: new Date().toISOString(),
        }),
      ]);
      this.logger.error(`[ARCH_AUDIT] failed error=${message}`);
    }
  }
}
