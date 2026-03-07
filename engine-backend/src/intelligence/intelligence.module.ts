import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { IntelligenceService } from './IntelligenceService';
import { IntelligenceController } from './intelligence.controller';
import { IntelligenceWorker } from './intelligence.worker';
import { RiskModule } from '../modules/risk/risk.module';
import { SpatialModule } from '../modules/common/spatial.module';
import { ReliabilityModule } from '../modules/reliability/reliability.module';
import { ForecastModule } from '../modules/forecast/forecast.module';
import { CellIntelligenceController } from './cell-intelligence.controller';

import { AnomalyDetectionService } from './anomaly-detection.service';

@Module({
  imports: [DatabaseModule, RiskModule, ReliabilityModule, ForecastModule, SpatialModule],
  providers: [IntelligenceService, IntelligenceWorker, AnomalyDetectionService],
  controllers: [IntelligenceController, CellIntelligenceController],
  exports: [IntelligenceService],
})
export class IntelligenceModule { }
