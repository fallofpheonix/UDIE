import { Body, Controller, Post } from '@nestjs/common';
import { RouteRiskDto } from './dto/route-risk.dto';
import { RiskService } from './risk.service';

@Controller(['route-risk', 'risk'])
export class RiskController {
  constructor(private readonly riskService: RiskService) {}

  @Post()
  calculate(@Body() payload: RouteRiskDto) {
    return this.riskService.calculateRouteRisk(payload);
  }
}
