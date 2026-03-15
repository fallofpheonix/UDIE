import { Injectable, Logger } from '@nestjs/common';
import * as h3 from 'h3-js';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { TelemetryDto } from './dto/routing.dto';

@Injectable()
export class TelemetryService {
  private readonly logger = new Logger(TelemetryService.name);

  constructor(private readonly db: DatabaseService) {}

  /**
   * Ingest a single vehicle telemetry record (Prompt 25).
   * Resolves the nearest road edge and persists to the telemetry table.
   */
  async ingest(dto: TelemetryDto): Promise<{ h3Index: string; edgeId: number | null }> {
    const h3Index = h3.latLngToCell(dto.lat, dto.lng, 9);

    // Attempt to snap vehicle to nearest road edge
    const edgeResult = await this.db.queryRead<QueryResultRow>(
      `SELECT id
       FROM road_edges
       ORDER BY geom <-> ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
       LIMIT 1`,
      [dto.lat, dto.lng],
    );
    const edgeId = edgeResult.rows[0]?.id ? Number(edgeResult.rows[0].id) : null;

    await this.db.query(
      `INSERT INTO vehicle_telemetry
         (vehicle_id, lat, lng, speed_kmh, heading, edge_id, h3_index)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [dto.vehicleId, dto.lat, dto.lng, dto.speedKmh, dto.heading ?? null, edgeId, h3Index],
    );

    this.logger.debug(`[TELEMETRY] vehicle=${dto.vehicleId} h3=${h3Index} speed=${dto.speedKmh}`);
    return { h3Index, edgeId };
  }

  /** Return recent positions for a vehicle */
  async getVehicleTrack(vehicleId: string, limitPoints = 100): Promise<Array<{
    lat: number;
    lng: number;
    speedKmh: number;
    recordedAt: string;
  }>> {
    const result = await this.db.queryRead<QueryResultRow>(
      `SELECT lat, lng, speed_kmh, recorded_at
       FROM vehicle_telemetry
       WHERE vehicle_id = $1
       ORDER BY recorded_at DESC
       LIMIT $2`,
      [vehicleId, limitPoints],
    );

    return result.rows.map((row) => ({
      lat: Number(row.lat),
      lng: Number(row.lng),
      speedKmh: Number(row.speed_kmh),
      recordedAt: String(row.recorded_at),
    }));
  }
}
