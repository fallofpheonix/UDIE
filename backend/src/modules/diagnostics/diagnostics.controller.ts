import { Controller, Get } from '@nestjs/common';
import { ArchitectureAuditService } from './architecture-audit.service';

@Controller('diagnostics')
export class DiagnosticsController {
  constructor(private readonly audit: ArchitectureAuditService) {}

  @Get('architecture')
  runArchitectureAudit() {
    return this.audit.runFullAudit();
  }
}
