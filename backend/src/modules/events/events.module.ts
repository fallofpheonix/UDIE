import { Module } from '@nestjs/common';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { LifecycleService } from './lifecycle.service';
import { DatabaseModule } from '../../database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [EventsController],
  providers: [EventsService, EventsRepository, LifecycleService],
  exports: [EventsService, EventsRepository, LifecycleService],
})
export class EventsModule { }
