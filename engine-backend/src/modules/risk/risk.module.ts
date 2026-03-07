import { Module } from '@nestjs/common';
import { RiskController } from './risk.controller';
import { RiskService } from './risk.service';
import { DatabaseModule } from '../../database/database.module';
import { RiskGridService } from './risk-grid.service';
import { AggregationWorker } from './aggregation.worker';
import { SpatialModule } from '../common/spatial.module';

@Module({
  imports: [DatabaseModule, SpatialModule],
  controllers: [RiskController],
  providers: [RiskService, RiskGridService, AggregationWorker],
  exports: [RiskService, RiskGridService],
})
export class RiskModule { }
