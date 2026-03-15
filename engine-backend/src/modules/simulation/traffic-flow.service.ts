import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { DigitalTwinService } from './digital-twin.service';
import { IngestTrafficSampleBatchDto } from './dto/ingest-traffic-sample-batch.dto';
import { IngestTrafficSampleDto } from './dto/ingest-traffic-sample.dto';

@Injectable()
export class TrafficFlowService {
  constructor(
    private readonly db: DatabaseService,
    private readonly digitalTwin: DigitalTwinService,
  ) {}

  async ingestSample(sample: IngestTrafficSampleDto) {
    const current = await this.digitalTwin.getCurrentStateForCoordinate(sample.lat, sample.lng);
    const next = await this.digitalTwin.upsertCellState({
      city_id: sample.city_id,
      lat: sample.lat,
      lng: sample.lng,
      traffic_density: sample.traffic_density,
      average_speed: sample.average_speed,
      disruption_weight: sample.disruption_weight,
      vehicle_count: sample.vehicle_count,
      timestamp: sample.observed_at,
    });
    if (!next) {
      throw new Error('digital twin state upsert returned no cell state');
    }

    await this.db.query(
      `
        INSERT INTO digital_twin_traffic_samples (
          cell_id,
          region_id,
          city_id,
          lat,
          lng,
          traffic_density,
          average_speed,
          vehicle_count,
          disruption_weight,
          heading_degrees,
          observed_at
        )
        VALUES (
          ($1::h3index)::bigint,
          $2::bigint,
          $3,
          $4,
          $5,
          $6,
          $7,
          $8::int,
          $9,
          $10,
          COALESCE($11::timestamptz, now())
        )
      `,
      [
        next.cellId,
        next.regionId,
        sample.city_id,
        sample.lat,
        sample.lng,
        sample.traffic_density,
        sample.average_speed,
        Math.trunc(sample.vehicle_count),
        sample.disruption_weight,
        sample.heading_degrees ?? null,
        sample.observed_at ?? null,
      ],
    );

    const delta = this.detectSuddenChange(current, next.state);
    if (delta.changed) {
      await this.db.query(
        `
          INSERT INTO digital_twin_state_alerts (
            cell_id,
            region_id,
            alert_type,
            severity,
            details,
            detected_at
          )
          VALUES (
            ($1::h3index)::bigint,
            $2::bigint,
            $3,
            $4,
            $5::jsonb,
            now()
          )
        `,
        [
          next.cellId,
          next.regionId,
          'SUDDEN_TRAFFIC_CHANGE',
          delta.severity,
          JSON.stringify(delta.details),
        ],
      );
    }

    return {
      cellId: next.cellId,
      regionId: next.regionId,
      changed: delta.changed,
      alertSeverity: delta.severity,
    };
  }

  async ingestBatch(batch: IngestTrafficSampleBatchDto) {
    const accepted = [];
    for (const sample of batch.samples) {
      accepted.push(await this.ingestSample(sample));
    }

    return {
      accepted: accepted.length,
      alerts: accepted.filter((entry) => entry.changed).length,
      results: accepted,
    };
  }

  async listAlerts(cellId: string, limit = 50) {
    const result = await this.db.queryRead<QueryResultRow>(
      `
        SELECT
          alert_type,
          severity,
          details,
          detected_at
        FROM digital_twin_state_alerts
        WHERE cell_id = ($1::h3index)::bigint
        ORDER BY detected_at DESC
        LIMIT $2
      `,
      [cellId, limit],
    );

    return {
      cellId,
      alerts: result.rows.map((row) => ({
        alertType: String(row.alert_type),
        severity: Number(row.severity ?? 0),
        details: row.details ?? {},
        detectedAt: new Date(String(row.detected_at)).toISOString(),
      })),
    };
  }

  private detectSuddenChange(
    previous: {
      trafficDensity: number;
      averageSpeed: number;
      vehicleCount: number;
      disruptionWeight: number;
    } | null,
    next: {
      trafficDensity: number;
      averageSpeed: number;
      vehicleCount: number;
      disruptionWeight: number;
    },
  ) {
    if (!previous) {
      return {
        changed: false,
        severity: 0,
        details: {},
      };
    }

    const speedDrop = previous.averageSpeed - next.averageSpeed;
    const densityJump = next.trafficDensity - previous.trafficDensity;
    const vehicleJump = next.vehicleCount - previous.vehicleCount;
    const disruptionJump = next.disruptionWeight - previous.disruptionWeight;

    const changed =
      speedDrop >= 12 ||
      densityJump >= 0.25 ||
      vehicleJump >= 30 ||
      disruptionJump >= 0.2;

    const severity = changed
      ? Math.min(
          5,
          1 +
            Math.floor(
              Math.max(
                speedDrop / 10,
                densityJump * 5,
                vehicleJump / 20,
                disruptionJump * 10,
              ),
            ),
        )
      : 0;

    return {
      changed,
      severity,
      details: {
        speedDrop,
        densityJump,
        vehicleJump,
        disruptionJump,
      },
    };
  }
}
