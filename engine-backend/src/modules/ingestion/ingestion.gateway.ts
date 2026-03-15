import { ConnectedSocket, MessageBody, SubscribeMessage, WebSocketGateway } from '@nestjs/websockets';
import { IngestionService, RawEvent } from './ingestion.service';
import { IngestSignalDto } from './dto/ingest-signal.dto';
import { IngestSignalBatchDto } from './dto/ingest-signal-batch.dto';

@WebSocketGateway({
  path: '/api/v1/ingestion/ws',
})
export class IngestionGateway {
  constructor(private readonly ingestionService: IngestionService) { }

  @SubscribeMessage('signal.ingest')
  async ingestSignal(
    @ConnectedSocket() _client: unknown,
    @MessageBody() payload: IngestSignalDto,
  ) {
    const result = await this.ingestionService.processRawEvent(this.toRawEvent(payload, 'WEBSOCKET'));
    return { event: 'signal.ack', data: result };
  }

  @SubscribeMessage('signal.ingest.batch')
  async ingestSignals(
    @ConnectedSocket() _client: unknown,
    @MessageBody() payload: IngestSignalBatchDto,
  ) {
    const result = await this.ingestionService.processRawEvents(
      payload.signals.map((signal) => this.toRawEvent(signal, 'WEBSOCKET')),
    );
    return { event: 'signal.batch.ack', data: result };
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
