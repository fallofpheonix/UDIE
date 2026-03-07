import { Body, Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import { CreateSimulationDto } from './dto/create-simulation.dto';
import { SimulationService } from './simulation.service';

@Controller('simulation')
export class SimulationController {
  constructor(private readonly service: SimulationService) { }

  @Post('events')
  @HttpCode(202)
  create(@Body() body: CreateSimulationDto) {
    return this.service.injectSimulationEvent(body);
  }

  @Get('scenario/:scenarioId')
  list(@Param('scenarioId') scenarioId: string) {
    return this.service.listScenario(scenarioId);
  }

  @Post('scenario/:scenarioId/run')
  run(
    @Param('scenarioId') scenarioId: string,
    @Body() body: { event_type: string; count: number; lat: number; lng: number }
  ) {
    return this.service.runScenario(scenarioId, body.event_type, body.count, body.lat, body.lng);
  }

  @Post('scenario/:scenarioId/clear')
  clear(@Param('scenarioId') scenarioId: string) {
    return this.service.clearScenario(scenarioId);
  }
}
