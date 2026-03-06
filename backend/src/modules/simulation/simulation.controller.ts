import { Body, Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import { CreateSimulationDto } from './dto/create-simulation.dto';
import { SimulationService } from './simulation.service';

@Controller('simulation')
export class SimulationController {
  constructor(private readonly service: SimulationService) {}

  @Post('events')
  @HttpCode(202)
  create(@Body() body: CreateSimulationDto) {
    return this.service.injectSimulationEvent(body);
  }

  @Get('scenario/:scenarioId')
  list(@Param('scenarioId') scenarioId: string) {
    return this.service.listScenario(scenarioId);
  }
}
