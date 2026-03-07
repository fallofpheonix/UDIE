import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { SpatialModule } from '../common/spatial.module';
import { CellInsightController } from './cell-insight.controller';
import { CellInsightService } from './cell-insight.service';

@Module({
  imports: [DatabaseModule, SpatialModule],
  controllers: [CellInsightController],
  providers: [CellInsightService],
})
export class CellInsightModule {}
