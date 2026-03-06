import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { RouteRiskDto } from './dto/route-risk.dto';
import { RiskService } from './risk.service';
import { SpatialValidationGuard } from '../../common/guards/spatial-validation.guard';

@Controller('risk')
@UseGuards(SpatialValidationGuard)
export class RiskController {
  constructor(private readonly riskService: RiskService) { }

  @Post()
  @HttpCode(200)
  calculate(@Body() payload: RouteRiskDto) {
    return this.riskService.calculateRouteRisk(payload);
  }
}
