import { Module } from '@nestjs/common';
import { ReliabilityService } from './reliability.service';
import { ReliabilityController } from './reliability.controller';
import { DatabaseModule } from '../../database/database.module';
import { SpatialModule } from '../common/spatial.module';

@Module({
    imports: [DatabaseModule, SpatialModule],
    providers: [ReliabilityService],
    controllers: [ReliabilityController],
    exports: [ReliabilityService],
})
export class ReliabilityModule { }
