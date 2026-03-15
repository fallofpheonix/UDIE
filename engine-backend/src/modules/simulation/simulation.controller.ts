import { Body, Controller, Get, HttpCode, Param, Post, Query } from '@nestjs/common';
import { BootstrapCityGridDto } from './dto/bootstrap-city-grid.dto';
import { CreateSimulationDto } from './dto/create-simulation.dto';
import { CreateDisruptionDto } from './dto/create-disruption.dto';
import { EstimateImpactRadiusDto } from './dto/estimate-impact-radius.dto';
import { EstimateEvacuationDto } from './dto/estimate-evacuation.dto';
import { GenerateRiskSurfaceDto } from './dto/generate-risk-surface.dto';
import { IngestTrafficSampleBatchDto } from './dto/ingest-traffic-sample-batch.dto';
import { IngestTrafficSampleDto } from './dto/ingest-traffic-sample.dto';
import { InjectSyntheticEventDto } from './dto/inject-synthetic-event.dto';
import { DisruptionPropagationService } from './disruption-propagation.service';
import { QueryCellHistoryDto } from './dto/query-cell-history.dto';
import { QueryCellNeighborsDto } from './dto/query-cell-neighbors.dto';
import { QueryCityGridDto } from './dto/query-city-grid.dto';
import { SimulateCongestionWaveDto } from './dto/simulate-congestion-wave.dto';
import { SimulateFutureHorizonDto } from './dto/simulate-future-horizon.dto';
import { UpsertCellStateDto } from './dto/upsert-cell-state.dto';
import { CongestionWaveService } from './congestion-wave.service';
import { DigitalTwinService } from './digital-twin.service';
import { ScenarioSimulationService } from './scenario-simulation.service';
import { SimulationService } from './simulation.service';
import { TrafficFlowService } from './traffic-flow.service';
import { TrafficSignalAIService } from './traffic-signal-ai.service';
import { ResetTrafficSignalEnvironmentDto } from './dto/reset-traffic-signal-environment.dto';
import { StepTrafficSignalEnvironmentDto } from './dto/step-traffic-signal-environment.dto';
import { TrainDqnDto } from './dto/train-dqn.dto';
import { TrainPpoDto } from './dto/train-ppo.dto';
import { TrafficSignalRLService } from './traffic-signal-rl.service';
import { BuildIntersectionGraphDto } from './dto/build-intersection-graph.dto';
import { TrainCoordinationDto } from './dto/train-coordination.dto';
import { PredictDownstreamCongestionDto } from './dto/predict-downstream-congestion.dto';
import { IngestSensorStreamDto } from './dto/ingest-sensor-stream.dto';
import { EstimateIntersectionStateDto } from './dto/estimate-intersection-state.dto';
import { ApplySignalControlDto } from './dto/apply-signal-control.dto';
import { RegisterNationalRegionDto } from './dto/register-national-region.dto';
import { QueryNationalViewportDto } from './dto/query-national-viewport.dto';
import { IntersectionGraphService } from './intersection-graph.service';
import { IntersectionCoordinationService } from './intersection-coordination.service';
import { DownstreamCongestionPredictionService } from './downstream-congestion-prediction.service';
import { TrafficSensorStreamService } from './traffic-sensor-stream.service';
import { IntersectionStateEstimatorService } from './intersection-state-estimator.service';
import { RealTimeSignalControlService } from './real-time-signal-control.service';
import { FailSafeTrafficControlService } from './fail-safe-traffic-control.service';
import { NationwideDigitalTwinService } from './nationwide-digital-twin.service';

@Controller('simulation')
export class SimulationController {
  constructor(
    private readonly service: SimulationService,
    private readonly digitalTwin: DigitalTwinService,
    private readonly trafficFlow: TrafficFlowService,
    private readonly disruptionPropagation: DisruptionPropagationService,
    private readonly congestionWave: CongestionWaveService,
    private readonly scenarioSimulation: ScenarioSimulationService,
    private readonly trafficSignalAI: TrafficSignalAIService,
    private readonly trafficSignalRL: TrafficSignalRLService,
    private readonly intersectionGraph: IntersectionGraphService,
    private readonly coordination: IntersectionCoordinationService,
    private readonly downstreamCongestion: DownstreamCongestionPredictionService,
    private readonly trafficSensorStream: TrafficSensorStreamService,
    private readonly intersectionStateEstimator: IntersectionStateEstimatorService,
    private readonly realTimeSignalControl: RealTimeSignalControlService,
    private readonly failSafeTrafficControl: FailSafeTrafficControlService,
    private readonly nationwideDigitalTwin: NationwideDigitalTwinService,
  ) { }

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

  @Post('grid/bootstrap')
  bootstrapGrid(@Body() body: BootstrapCityGridDto) {
    return this.digitalTwin.bootstrapGrid(body);
  }

  @Get('grid/cells')
  listGridCells(@Query() query: QueryCityGridDto) {
    return this.digitalTwin.listCellsForViewport(query);
  }

  @Get('grid/cells/:cellId/neighbors')
  listNeighbors(@Param('cellId') cellId: string, @Query() query: QueryCellNeighborsDto) {
    return this.digitalTwin.getNeighbors(cellId, query.k);
  }

  @Get('grid/cells/:cellId/history')
  getHistory(@Param('cellId') cellId: string, @Query() query: QueryCellHistoryDto) {
    return this.digitalTwin.getCellHistory(cellId, query);
  }

  @Get('grid/cells/:cellId/alerts')
  getAlerts(@Param('cellId') cellId: string, @Query('limit') limit?: string) {
    return this.trafficFlow.listAlerts(cellId, limit ? Number(limit) : 50);
  }

  @Post('grid/state')
  @HttpCode(202)
  upsertGridState(@Body() body: UpsertCellStateDto) {
    return this.digitalTwin.upsertCellState(body);
  }

  @Post('traffic/stream')
  @HttpCode(202)
  ingestTrafficSample(@Body() body: IngestTrafficSampleDto) {
    return this.trafficFlow.ingestSample(body);
  }

  @Post('traffic/stream/batch')
  @HttpCode(202)
  ingestTrafficBatch(@Body() body: IngestTrafficSampleBatchDto) {
    return this.trafficFlow.ingestBatch(body);
  }

  @Post('disruptions')
  @HttpCode(202)
  createDisruption(@Body() body: CreateDisruptionDto) {
    return this.disruptionPropagation.createDisruption(body);
  }

  @Get('disruptions/:disruptionId/influence')
  getDisruptionInfluence(@Param('disruptionId') disruptionId: string) {
    return this.disruptionPropagation.listInfluence(disruptionId);
  }

  @Post('congestion-wave')
  simulateCongestionWave(@Body() body: SimulateCongestionWaveDto) {
    return this.congestionWave.simulate(body);
  }

  @Post('disruptions/impact-radius')
  estimateImpactRadius(@Body() body: EstimateImpactRadiusDto) {
    return this.congestionWave.estimateImpactRadius(body);
  }

  @Post('risk-surface')
  generateRiskSurface(@Body() body: GenerateRiskSurfaceDto) {
    return this.scenarioSimulation.generateRiskSurface(body);
  }

  @Post('scenarios/synthetic')
  @HttpCode(202)
  injectSyntheticEvent(@Body() body: InjectSyntheticEventDto) {
    return this.scenarioSimulation.injectSyntheticEvent(body);
  }

  @Post('horizon')
  simulateHorizon(@Body() body: SimulateFutureHorizonDto) {
    return this.scenarioSimulation.simulateHorizons(body);
  }

  @Post('evacuation')
  estimateEvacuation(@Body() body: EstimateEvacuationDto) {
    return this.scenarioSimulation.estimateEvacuation(body);
  }

  @Get('traffic-signals/actions')
  listTrafficSignalActions() {
    return this.trafficSignalAI.listActions();
  }

  @Get('traffic-signals/intersections/:intersectionId/agent')
  getIntersectionAgent(@Param('intersectionId') intersectionId: string, @Query('city_id') cityId?: string) {
    return this.trafficSignalAI.getIntersectionAgent(intersectionId, cityId);
  }

  @Post('traffic-signals/environment/reset')
  resetTrafficSignalEnvironment(@Body() body: ResetTrafficSignalEnvironmentDto) {
    return this.trafficSignalAI.resetEnvironment(body);
  }

  @Post('traffic-signals/environment/step')
  stepTrafficSignalEnvironment(@Body() body: StepTrafficSignalEnvironmentDto) {
    return this.trafficSignalAI.stepEnvironment(body);
  }

  @Post('traffic-signals/train/dqn')
  trainTrafficSignalsDqn(@Body() body: TrainDqnDto) {
    return this.trafficSignalRL.trainDqn(body);
  }

  @Post('traffic-signals/train/ppo')
  trainTrafficSignalsPpo(@Body() body: TrainPpoDto) {
    return this.trafficSignalRL.trainPpo(body);
  }

  @Post('traffic-signals/graph/build')
  buildIntersectionGraph(@Body() body: BuildIntersectionGraphDto) {
    return this.intersectionGraph.buildGraph(body);
  }

  @Get('traffic-signals/graph')
  getIntersectionGraph(@Query('city_id') cityId?: string) {
    return this.intersectionGraph.getGraph(cityId);
  }

  @Post('traffic-signals/coordination/train')
  trainCoordination(@Body() body: TrainCoordinationDto) {
    return this.coordination.train(body);
  }

  @Get('traffic-signals/coordination')
  coordinateTrafficSignals(@Query('city_id') cityId?: string) {
    return this.coordination.coordinate(cityId);
  }

  @Post('traffic-signals/downstream-congestion')
  predictDownstreamCongestion(@Body() body: PredictDownstreamCongestionDto) {
    return this.downstreamCongestion.predict(body);
  }

  @Post('traffic-sensors/kafka/ingest')
  @HttpCode(202)
  ingestTrafficSensorKafka(@Body() body: IngestSensorStreamDto) {
    return this.trafficSensorStream.ingestKafkaEnvelope(body);
  }

  @Get('traffic-sensors/kafka/recent')
  recentTrafficSensorEvents(@Query('limit') limit?: string) {
    return this.trafficSensorStream.recentStreamEvents(limit ? Number(limit) : 50);
  }

  @Post('traffic-signals/intersections/state-estimate')
  estimateIntersectionState(@Body() body: EstimateIntersectionStateDto) {
    return this.intersectionStateEstimator.estimate(body);
  }

  @Post('traffic-signals/control/apply')
  applyRealTimeSignalControl(@Body() body: ApplySignalControlDto) {
    return this.realTimeSignalControl.dispatch(body);
  }

  @Post('traffic-signals/control/fail-safe')
  applyFailSafeSignalControl(@Body() body: ApplySignalControlDto) {
    return this.failSafeTrafficControl.dispatch(body);
  }

  @Post('national/regions/register')
  registerNationalRegion(@Body() body: RegisterNationalRegionDto) {
    return this.nationwideDigitalTwin.registerRegion(body);
  }

  @Get('national/view')
  getNationalRegionalView(@Query() query: QueryNationalViewportDto) {
    return this.nationwideDigitalTwin.regionalView(query);
  }

  @Get('national/systems')
  getNationalRegionalSystems(@Query() query: QueryNationalViewportDto) {
    return this.nationwideDigitalTwin.regionalSystems(query);
  }
}
