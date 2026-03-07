import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { ArchitectureAuditService } from './architecture-audit.service';

@Injectable()
export class SystemSelfDiagnosisService {
  constructor(
    private readonly audit: ArchitectureAuditService,
    private readonly db: DatabaseService,
  ) {}

  async runNightly(): Promise<void> {
    const report = await this.audit.runFullAudit();

    await this.db.query('SELECT set_system_state($1, $2::jsonb)', [
      'self_diagnosis_nightly',
      JSON.stringify(report),
    ]);
  }
}
