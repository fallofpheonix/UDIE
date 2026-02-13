import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { RouteRiskDto } from './dto/route-risk.dto';
import { RiskService } from './risk.service';

@Controller(['route-risk', 'risk'])
export class RiskController {
  constructor(private readonly riskService: RiskService) {}

  @Post()
  @HttpCode(200)
  calculate(@Body() payload: RouteRiskDto) {
    return this.riskService.calculateRouteRisk(payload);
  }
}
