import { Controller, Get } from '@nestjs/common';
import { ArchitectureAuditService } from './architecture-audit.service';

@Controller('diagnostics')
export class DiagnosticsController {
  constructor(private readonly audit: ArchitectureAuditService) {}

  @Get('architecture')
  runArchitectureAudit() {
    return this.audit.runFullAudit();
  }

  @Get('rebuild')
  async runRebuildAudit() {
    try {
      const rebuild = await this.audit.runRebuildCheck();
      return {
        status: rebuild.ok ? 'SUCCESS' : 'FAILED',
        deterministic: rebuild.ok,
        before: rebuild.before,
        after: rebuild.after,
        checkedAt: new Date().toISOString(),
      };
    } catch (error) {
      return {
        status: 'FAILED',
        deterministic: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        checkedAt: new Date().toISOString(),
      };
    }
  }
}
