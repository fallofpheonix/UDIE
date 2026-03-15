import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { IngestSensorStreamDto } from './dto/ingest-sensor-stream.dto';
import { TrafficFlowService } from './traffic-flow.service';

@Injectable()
export class TrafficSensorStreamService {
  constructor(
    private readonly db: DatabaseService,
    private readonly trafficFlow: TrafficFlowService,
  ) {}

  async ingestKafkaEnvelope(dto: IngestSensorStreamDto) {
    const topic = dto.topic ?? this.defaultTopic(dto.source_type);
    const result = await this.trafficFlow.ingestSample({
      city_id: dto.city_id,
      lat: dto.lat,
      lng: dto.lng,
      traffic_density: dto.traffic_density,
      average_speed: dto.average_speed,
      disruption_weight: dto.disruption_weight,
      vehicle_count: dto.vehicle_count,
      observed_at: dto.observed_at,
    });

    await this.db.query(
      `
        INSERT INTO traffic_sensor_stream_events (
          topic,
          partition_id,
          source_type,
          city_id,
          lat,
          lng,
          payload,
          observed_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, COALESCE($8::timestamptz, now()))
      `,
      [
        topic,
        dto.partition ?? 0,
        dto.source_type,
        dto.city_id,
        dto.lat,
        dto.lng,
        JSON.stringify(dto),
        dto.observed_at ?? null,
      ],
    );

    return {
      topic,
      partition: dto.partition ?? 0,
      accepted: true,
      twinUpdate: result,
    };
  }

  async recentStreamEvents(limit = 50) {
    const result = await this.db.queryRead<QueryResultRow>(
      `
        SELECT topic, partition_id, source_type, city_id, observed_at
        FROM traffic_sensor_stream_events
        ORDER BY observed_at DESC
        LIMIT $1
      `,
      [limit],
    );

    return {
      events: result.rows.map((row) => ({
        topic: String(row.topic),
        partition: Number(row.partition_id ?? 0),
        sourceType: String(row.source_type),
        cityId: String(row.city_id),
        observedAt: new Date(String(row.observed_at)).toISOString(),
      })),
    };
  }

  private defaultTopic(sourceType: string) {
    if (sourceType === 'LOOP_DETECTOR') return 'traffic.loop';
    if (sourceType === 'CAMERA_SENSOR') return 'traffic.camera';
    if (sourceType === 'VEHICLE_TELEMETRY') return 'traffic.telemetry';
    return 'traffic.gps';
  }
}
