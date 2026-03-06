import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { EventsService } from './events.service';
import { QueryEventsDto } from './dto/query-events.dto';
import { SpatialValidationGuard } from '../../common/guards/spatial-validation.guard';

@Controller('events')
@UseGuards(SpatialValidationGuard)
export class EventsController {
  constructor(private readonly eventsService: EventsService) { }

  @Get()
  getEvents(@Query() query: QueryEventsDto) {
    return this.eventsService.getEvents(query);
  }
}
