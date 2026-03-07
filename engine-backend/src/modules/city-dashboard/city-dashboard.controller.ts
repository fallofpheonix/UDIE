import { Controller, Get, Query } from '@nestjs/common';
import { CityDashboardService } from './city-dashboard.service';
import { QueryCityDashboardDto } from './dto/query-city-dashboard.dto';

@Controller('city-dashboard')
export class CityDashboardController {
  constructor(private readonly service: CityDashboardService) {}

  @Get()
  getDashboard(@Query() query: QueryCityDashboardDto) {
    return this.service.getDashboard(query);
  }
}
