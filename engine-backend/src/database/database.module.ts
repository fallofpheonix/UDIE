import { Module } from '@nestjs/common';
import { DatabaseService } from './database.service';
import { PartitionManagementService } from '../modules/database/partition-management.service';

@Module({
  providers: [DatabaseService, PartitionManagementService],
  exports: [DatabaseService, PartitionManagementService],
})
export class DatabaseModule { }
