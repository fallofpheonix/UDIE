import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { SpatialValidationGuard } from '../../common/guards/spatial-validation.guard';
import { QueryRiskSnapshotsDto } from './dto/query-risk-snapshots.dto';
import { RiskSnapshotsService } from './risk-snapshots.service';

@Controller('risk-snapshots')
@UseGuards(SpatialValidationGuard)
export class RiskSnapshotsController {
  constructor(private readonly service: RiskSnapshotsService) {}

  @Get()
  list(@Query() query: QueryRiskSnapshotsDto) {
    return this.service.listSnapshots(query);
  }
}
