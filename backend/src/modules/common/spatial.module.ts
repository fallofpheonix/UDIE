import { Module, Global } from '@nestjs/common';
import { SpatialService } from './spatial.service';
import { PartitionManagementService } from '../database/partition-management.service';
import { DatabaseModule } from '../../database/database.module';
import { ObservabilityService } from './observability.service';

@Global()
@Module({
    imports: [DatabaseModule],
    providers: [SpatialService, PartitionManagementService, ObservabilityService],
    exports: [SpatialService, PartitionManagementService, ObservabilityService],
})
export class SpatialModule { }
