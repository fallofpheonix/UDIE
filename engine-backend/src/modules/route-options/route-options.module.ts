import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { SpatialModule } from '../common/spatial.module';
import { RouteOptionsController } from './route-options.controller';
import { RoadGraphMaterializationService } from './road-graph-materialization.service';
import { RouteCacheService } from './route-cache.service';
import { RouteOptionsService } from './route-options.service';

@Module({
  imports: [DatabaseModule, SpatialModule],
  controllers: [RouteOptionsController],
  providers: [
    RouteOptionsService,
    RouteCacheService,
    RoadGraphMaterializationService,
  ],
})
export class RouteOptionsModule {}
