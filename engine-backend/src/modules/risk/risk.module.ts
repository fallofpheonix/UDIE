import { Module } from '@nestjs/common';
import { RiskController } from './risk.controller';
import { RiskService } from './risk.service';
import { DatabaseModule } from '../../database/database.module';
import { RiskGridService } from './risk-grid.service';
import { AggregationWorker } from './aggregation.worker';
import { SpatialModule } from '../common/spatial.module';
import { SpatialRiskFieldService } from './spatial-risk-field.service';
import { MaterializationService } from './materialization.service';
import { RiskSurfaceCacheService } from './risk-surface-cache.service';
import { RiskStreamService } from './risk-stream.service';
import { RiskStreamGateway } from './risk-stream.gateway';

@Module({
  imports: [DatabaseModule, SpatialModule],
  controllers: [RiskController],
  providers: [RiskService, RiskGridService, AggregationWorker, SpatialRiskFieldService, MaterializationService, RiskSurfaceCacheService, RiskStreamService, RiskStreamGateway],
  exports: [RiskService, RiskGridService, SpatialRiskFieldService, RiskSurfaceCacheService, RiskStreamService],
})
export class RiskModule { }
