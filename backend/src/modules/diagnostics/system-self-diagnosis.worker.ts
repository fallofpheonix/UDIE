import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { SystemSelfDiagnosisService } from './system-self-diagnosis.service';

@Injectable()
export class SystemSelfDiagnosisWorker {
  private readonly logger = new Logger(SystemSelfDiagnosisWorker.name);

  constructor(private readonly service: SystemSelfDiagnosisService) {}

  @Cron('0 30 2 * * *')
  async run(): Promise<void> {
    try {
      await this.service.runNightly();
      this.logger.log('[SELF_DIAGNOSIS] status=healthy');
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.error(`[SELF_DIAGNOSIS] status=failed error=${message}`);
    }
  }
}
