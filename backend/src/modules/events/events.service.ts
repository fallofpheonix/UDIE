import { Injectable } from '@nestjs/common';
import { QueryEventsDto } from './dto/query-events.dto';
import { EventsRepository } from './events.repository';

@Injectable()
export class EventsService {
  constructor(private readonly eventsRepository: EventsRepository) {}

  getEvents(query: QueryEventsDto) {
    return this.eventsRepository.findByBoundingBox(query);
  }
}
