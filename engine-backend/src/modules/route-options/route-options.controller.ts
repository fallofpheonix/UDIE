import { Body, Controller, Get, HttpCode, Post, Query } from '@nestjs/common';
import {
  EtaQueryDto,
  RerouteDto,
  RouteOptionsDto,
  TrafficQueryDto,
} from './dto/route-options.dto';
import { RouteOptionsService } from './route-options.service';

@Controller()
export class RouteOptionsController {
  constructor(private readonly service: RouteOptionsService) {}

  @Post('route-options')
  @HttpCode(200)
  getRouteOptions(@Body() body: RouteOptionsDto) {
    return this.service.getOptions(body);
  }

  @Post('route')
  @HttpCode(200)
  route(@Body() body: RouteOptionsDto) {
    return this.service.route(body);
  }

  @Post('reroute')
  @HttpCode(200)
  reroute(@Body() body: RerouteDto) {
    return this.service.reroute(body);
  }

  @Get('traffic')
  getTraffic(@Query() query: TrafficQueryDto) {
    return this.service.traffic(query);
  }

  @Post('eta')
  @HttpCode(200)
  getEta(@Body() body: EtaQueryDto) {
    return this.service.eta(body);
  }
}
