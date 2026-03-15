import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { IngestionService, RawEvent } from './ingestion.service';
import { IngestSignalDto } from './dto/ingest-signal.dto';
import { IngestSignalBatchDto } from './dto/ingest-signal-batch.dto';

@Controller('ingestion')
export class IngestionController {
  constructor(private readonly ingestionService: IngestionService) { }

  @Post('signals')
  @HttpCode(200)
  ingestSignal(@Body() payload: IngestSignalDto) {
    return this.ingestionService.processRawEvent(this.toRawEvent(payload, 'REST'));
  }

  @Post('signals/batch')
  @HttpCode(200)
  ingestSignals(@Body() payload: IngestSignalBatchDto) {
    return this.ingestionService.processRawEvents(
      payload.signals.map((signal) => this.toRawEvent(signal, 'REST')),
    );
  }

  private toRawEvent(payload: IngestSignalDto, transport: RawEvent['transport']): RawEvent {
    return {
      source_id: payload.sourceId,
      source_type: payload.sourceCategory,
      lat: payload.lat,
      lng: payload.lng,
      event_type: payload.eventType,
      severity_hint: payload.severity,
      confidence_hint: payload.confidence,
      observed_at: payload.observedAt,
      text: payload.text,
      metadata: payload.metadata,
      transport,
    };
  }
}
