import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { EventsService } from './events.service';
import { QueryEventsDto } from './dto/query-events.dto';
import { CreateEventDto } from './dto/create-event.dto';
import { SpatialValidationGuard } from '../../common/guards/spatial-validation.guard';
import { Body, Post, HttpCode } from '@nestjs/common';

@Controller('events')
@UseGuards(SpatialValidationGuard)
export class EventsController {
  constructor(private readonly eventsService: EventsService) { }

  @Get()
  getEvents(@Query() query: QueryEventsDto) {
    return this.eventsService.getEvents(query);
  }

  @Post()
  @HttpCode(201)
  async create(@Body() dto: CreateEventDto) {
    const event = await this.eventsService.create(dto);
    return {
      status: 'SUCCESS',
      event_id: event.id
    };
  }
}
