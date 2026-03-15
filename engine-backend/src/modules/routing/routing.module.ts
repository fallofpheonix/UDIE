import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { RoadGraphService } from './road-graph.service';
import { PathfindingService } from './pathfinding.service';
import { TrafficService } from './traffic.service';
import { NavigationService } from './navigation.service';
import { TelemetryService } from './telemetry.service';
import { RoutingController } from './routing.controller';

@Module({
  imports: [DatabaseModule],
  controllers: [RoutingController],
  providers: [
    RoadGraphService,
    PathfindingService,
    TrafficService,
    NavigationService,
    TelemetryService,
  ],
  exports: [RoadGraphService, PathfindingService, TrafficService],
})
export class RoutingModule {}
