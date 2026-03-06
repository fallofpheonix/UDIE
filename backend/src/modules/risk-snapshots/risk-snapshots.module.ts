import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { RiskSnapshotsController } from './risk-snapshots.controller';
import { RiskSnapshotsService } from './risk-snapshots.service';
import { SnapshotWorker } from './snapshot.worker';

@Module({
  imports: [DatabaseModule],
  providers: [RiskSnapshotsService, SnapshotWorker],
  controllers: [RiskSnapshotsController],
})
export class RiskSnapshotsModule {}
