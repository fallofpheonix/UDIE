import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { SpatialModule } from '../common/spatial.module';
import { CongestionWaveService } from './congestion-wave.service';
import { ScenarioOperatorController } from './scenario-operator.controller';
import { SimulationController } from './simulation.controller';
import { DigitalTwinStateStoreService } from './digital-twin-state-store.service';
import { DigitalTwinTickService } from './digital-twin-tick.service';
import { DigitalTwinService } from './digital-twin.service';
import { DisruptionPropagationService } from './disruption-propagation.service';
import { ScenarioSimulationService } from './scenario-simulation.service';
import { SimulationService } from './simulation.service';
import { TrafficFlowService } from './traffic-flow.service';
import { TrafficSignalAIService } from './traffic-signal-ai.service';
import { TrafficSignalRLService } from './traffic-signal-rl.service';
import { IntersectionGraphService } from './intersection-graph.service';
import { IntersectionCoordinationService } from './intersection-coordination.service';
import { DownstreamCongestionPredictionService } from './downstream-congestion-prediction.service';
import { TrafficSensorStreamService } from './traffic-sensor-stream.service';
import { IntersectionStateEstimatorService } from './intersection-state-estimator.service';
import { RealTimeSignalControlService } from './real-time-signal-control.service';
import { FailSafeTrafficControlService } from './fail-safe-traffic-control.service';
import { NationwideDigitalTwinService } from './nationwide-digital-twin.service';

@Module({
  imports: [DatabaseModule, SpatialModule],
  controllers: [SimulationController, ScenarioOperatorController],
  providers: [
    SimulationService,
    DigitalTwinService,
    DigitalTwinStateStoreService,
    DigitalTwinTickService,
    TrafficFlowService,
    TrafficSignalAIService,
    TrafficSignalRLService,
    IntersectionGraphService,
    IntersectionCoordinationService,
    DownstreamCongestionPredictionService,
    TrafficSensorStreamService,
    IntersectionStateEstimatorService,
    RealTimeSignalControlService,
    FailSafeTrafficControlService,
    NationwideDigitalTwinService,
    DisruptionPropagationService,
    CongestionWaveService,
    ScenarioSimulationService,
  ],
})
export class SimulationModule {}
