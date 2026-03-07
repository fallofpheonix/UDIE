import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { RouteOptionsDto } from './dto/route-options.dto';
import { RouteOptionsService } from './route-options.service';

@Controller('route-options')
export class RouteOptionsController {
  constructor(private readonly service: RouteOptionsService) {}

  @Post()
  @HttpCode(200)
  getRouteOptions(@Body() body: RouteOptionsDto) {
    return this.service.getOptions(body);
  }
}
