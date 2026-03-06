import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { DiagnosticsController } from './diagnostics.controller';
import { ArchitectureAuditService } from './architecture-audit.service';
import { QueryPlanMonitor } from './query-plan-monitor.service';
import { RiskModelMonitor } from './risk-model-monitor.service';
import { ArchitectureAuditWorker } from './architecture-audit.worker';
import { SystemSelfDiagnosisService } from './system-self-diagnosis.service';
import { SystemSelfDiagnosisWorker } from './system-self-diagnosis.worker';
import { PerformanceSentinel } from './performance-sentinel.service';
import { PerformanceSentinelWorker } from './performance-sentinel.worker';
import { SpatialModule } from '../common/spatial.module';

@Module({
  imports: [DatabaseModule, SpatialModule],
  controllers: [DiagnosticsController],
  providers: [
    ArchitectureAuditService,
    QueryPlanMonitor,
    RiskModelMonitor,
    PerformanceSentinel,
    PerformanceSentinelWorker,
    ArchitectureAuditWorker,
    SystemSelfDiagnosisService,
    SystemSelfDiagnosisWorker,
  ],
  exports: [ArchitectureAuditService],
})
export class DiagnosticsModule {}
