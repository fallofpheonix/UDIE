import { Module } from '@nestjs/common';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { LifecycleService } from './lifecycle.service';
import { ProjectionService } from './projection.service';
import { DisruptionIdentityService } from './disruption-identity.service';
import { EventCorrelationService } from './event-correlation.service';
import { DatabaseModule } from '../../database/database.module';
import { SpatialModule } from '../common/spatial.module';
import { RiskModule } from '../risk/risk.module';

@Module({
  imports: [DatabaseModule, SpatialModule, RiskModule],
  controllers: [EventsController],
  providers: [EventsService, EventsRepository, LifecycleService, ProjectionService, DisruptionIdentityService, EventCorrelationService],
  exports: [EventsService, EventsRepository, LifecycleService, ProjectionService, DisruptionIdentityService],
})
export class EventsModule { }
