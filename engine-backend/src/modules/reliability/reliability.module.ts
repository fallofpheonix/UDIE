import { Module } from '@nestjs/common';
import { ReliabilityService } from './reliability.service';
import { ReliabilityController } from './reliability.controller';
import { ErrorLogService } from './error-log.service';
import { DatabaseModule } from '../../database/database.module';
import { SpatialModule } from '../common/spatial.module';
import { AIResolverService } from './ai-resolver.service';
import { SpatialDiffusionWorker } from './spatial-diffusion.worker';
import { RiskModule } from '../risk/risk.module';

@Module({
    imports: [DatabaseModule, SpatialModule, RiskModule],
    providers: [ReliabilityService, ErrorLogService, AIResolverService, SpatialDiffusionWorker],
    controllers: [ReliabilityController],
    exports: [ReliabilityService, ErrorLogService],
})
export class ReliabilityModule { }
