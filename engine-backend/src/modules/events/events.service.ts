import { Injectable } from '@nestjs/common';
import { QueryEventsDto } from './dto/query-events.dto';
import { CreateEventDto } from './dto/create-event.dto';
import { EventsRepository } from './events.repository';
import { IngestionService } from '../ingestion/ingestion.service';

@Injectable()
export class EventsService {
  constructor(
    private readonly eventsRepository: EventsRepository,
    private readonly ingestionService: IngestionService,
  ) { }

  getEvents(query: QueryEventsDto) {
    return this.eventsRepository.findByBoundingBox(query);
  }

  async create(dto: CreateEventDto) {
    const normalizedEventType = this.normalizeEventType(dto.type);
    const severity = Math.max(1, Math.min(5, Math.round(dto.weight * 4) + 1));
    const result = await this.ingestionService.processRawEvent({
      source_id: 'events-api',
      source_type: 'MANUAL_USER_REPORT',
      lat: dto.lat,
      lng: dto.lng,
      event_type: normalizedEventType,
      severity_hint: severity,
      confidence_hint: dto.confidence ?? 1,
      metadata: {
        original_type: dto.type,
        original_weight: dto.weight,
        ingress: 'events_api',
      },
      transport: 'REST',
    });

    if (result.status !== 'SUCCESS' || !result.logId) {
      throw new Error(result.reason ?? 'event_ingestion_failed');
    }

    return { id: result.logId };
  }

  private normalizeEventType(type: string) {
    const normalized = String(type).toUpperCase().trim();
    switch (normalized) {
      case 'ACCIDENT':
        return 'ACCIDENT';
      case 'CONSTRUCTION':
      case 'INFRASTRUCTURE':
        return 'CONSTRUCTION';
      case 'ROAD_CLOSURE':
      case 'ROAD_BLOCK':
        return 'ROAD_BLOCK';
      case 'WEATHER':
      case 'WATER_LOGGING':
        return 'WATER_LOGGING';
      case 'CRIME':
      case 'PROTEST':
        return 'PROTEST';
      case 'TRAFFIC':
      case 'HEAVY_TRAFFIC':
      case 'TEST':
      case 'TEST_EVENT':
      default:
        return 'HEAVY_TRAFFIC';
    }
  }
}
