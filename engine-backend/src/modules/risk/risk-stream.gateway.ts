import { ConnectedSocket, MessageBody, SubscribeMessage, WebSocketGateway } from '@nestjs/websockets';
import { WebSocket } from 'ws';
import { RiskStreamService } from './risk-stream.service';
import { RiskSurfaceBounds } from './risk-surface-cache.service';

type RiskSurfaceSubscriptionPayload = RiskSurfaceBounds & {
  limit?: number;
};

@WebSocketGateway({
  path: '/api/v1/risk/ws',
})
export class RiskStreamGateway {
  constructor(private readonly riskStreamService: RiskStreamService) { }

  handleDisconnect(client: WebSocket) {
    this.riskStreamService.removeSubscription(client);
  }

  @SubscribeMessage('risk.surface.subscribe')
  async subscribe(
    @ConnectedSocket() client: WebSocket,
    @MessageBody() payload: RiskSurfaceSubscriptionPayload,
  ) {
    const bounds = this.validateBounds(payload);
    this.riskStreamService.upsertSubscription(client, bounds, payload?.limit);
    await this.riskStreamService.syncClient(client);
    return { event: 'risk.surface.ack', data: { status: 'subscribed' } };
  }

  @SubscribeMessage('risk.surface.unsubscribe')
  unsubscribe(@ConnectedSocket() client: WebSocket) {
    this.riskStreamService.removeSubscription(client);
    return { event: 'risk.surface.ack', data: { status: 'unsubscribed' } };
  }

  private validateBounds(payload: RiskSurfaceSubscriptionPayload): RiskSurfaceBounds {
    const minLat = Number(payload?.minLat);
    const maxLat = Number(payload?.maxLat);
    const minLng = Number(payload?.minLng);
    const maxLng = Number(payload?.maxLng);

    if (![minLat, maxLat, minLng, maxLng].every(Number.isFinite)) {
      throw new Error('Invalid risk stream bounds.');
    }

    return {
      minLat: Math.min(minLat, maxLat),
      maxLat: Math.max(minLat, maxLat),
      minLng: Math.min(minLng, maxLng),
      maxLng: Math.max(minLng, maxLng),
    };
  }
}
