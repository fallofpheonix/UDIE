import { Body, Controller, Get, HttpCode, Post, Query } from '@nestjs/common';
import { QuerySimulationResultsDto } from './dto/query-simulation-results.dto';
import { SimulateEventDto } from './dto/simulate-event.dto';
import { ScenarioSimulationService } from './scenario-simulation.service';

@Controller()
export class ScenarioOperatorController {
  constructor(private readonly scenarios: ScenarioSimulationService) {}

  @Post('simulate_event')
  @HttpCode(202)
  simulateEvent(@Body() body: SimulateEventDto) {
    return this.scenarios.runOperatorSimulation(body);
  }

  @Get('simulation_results')
  getSimulationResults(@Query() query: QuerySimulationResultsDto) {
    return this.scenarios.getSimulationResults(query);
  }

  @Get('risk_predictions')
  getRiskPredictions(@Query() query: QuerySimulationResultsDto) {
    return this.scenarios.getRiskPredictions(query);
  }
}
