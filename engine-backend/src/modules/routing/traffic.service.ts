import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import * as h3 from 'h3-js';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { RoadGraphService } from './road-graph.service';

export interface TrafficState {
  edgeId: number;
  averageSpeedKmh: number;
  vehicleDensity: number;
  disruptionWeight: number;
  effectiveWeight: number;
  updatedAt: string;
}

export interface TrafficForecast {
  edgeId: number;
  h3Index: string;
  forecast5m: number;
  forecast15m: number;
  forecast30m: number;
  generatedAt: string;
}

/** Congestion thresholds (align with migration 045 model parameters) */
const CONGESTION_DENSITY_THRESHOLD = 0.7;
const CONGESTION_SPEED_RATIO_HEAVY = 0.4;
const CONGESTION_SPEED_RATIO_MODERATE = 0.7;
const CONGESTION_SPEED_PENALTY_HEAVY = 2.5;
const CONGESTION_SPEED_PENALTY_MODERATE = 1.5;

@Injectable()
export class TrafficService {
  private readonly logger = new Logger(TrafficService.name);

  /** In-memory traffic state indexed by edge_id */
  private readonly trafficCache = new Map<number, TrafficState>();

  constructor(
    private readonly db: DatabaseService,
    private readonly roadGraph: RoadGraphService,
  ) {}

  /**
   * Background worker: updates edge weights every 10 seconds (Prompt 9).
   * Reads recent telemetry, computes new edge weights, writes to DB and
   * updates in-memory graph.
   */
  @Cron(CronExpression.EVERY_10_SECONDS)
  async updateEdgeWeights(): Promise<void> {
    try {
      const result = await this.db.queryRead<QueryResultRow>(
        `WITH recent AS (
           SELECT edge_id,
                  AVG(speed_kmh)   AS avg_speed,
                  COUNT(*)::float  AS density
           FROM   vehicle_telemetry
           WHERE  recorded_at >= now() - interval '30 seconds'
             AND  edge_id IS NOT NULL
           GROUP BY edge_id
         ),
         edges AS (
           SELECT e.id, e.speed_limit_kmh, e.base_travel_time_s,
                  e.lanes, e.risk_score,
                  r.avg_speed, r.density
           FROM   road_edges e
           JOIN   recent r ON r.edge_id = e.id
         )
         SELECT id,
                speed_limit_kmh,
                base_travel_time_s,
                lanes,
                risk_score,
                COALESCE(avg_speed, speed_limit_kmh)   AS avg_speed,
                COALESCE(density, 0)                   AS density
         FROM edges`,
      );

      for (const row of result.rows) {
        const edgeId = Number(row.id);
        const speedLimit = Number(row.speed_limit_kmh);
        const baseTravelTime = Number(row.base_travel_time_s);
        const avgSpeed = Number(row.avg_speed);
        const density = Number(row.density);
        const riskScore = Number(row.risk_score);

        // Congestion penalty (Prompt 10): penalise when density/speed drops
        const speedRatio = avgSpeed / Math.max(speedLimit, 1);
        let disruptionWeight = 1.0;
        if (density > CONGESTION_DENSITY_THRESHOLD) disruptionWeight += density * 1.5;
        if (speedRatio < CONGESTION_SPEED_RATIO_HEAVY) disruptionWeight *= CONGESTION_SPEED_PENALTY_HEAVY;
        else if (speedRatio < CONGESTION_SPEED_RATIO_MODERATE) disruptionWeight *= CONGESTION_SPEED_PENALTY_MODERATE;

        // Risk-aware cost integration (Prompt 11)
        const effectiveWeight = baseTravelTime * disruptionWeight + riskScore * 3600 * 2;

        const state: TrafficState = {
          edgeId,
          averageSpeedKmh: avgSpeed,
          vehicleDensity: density,
          disruptionWeight,
          effectiveWeight,
          updatedAt: new Date().toISOString(),
        };

        this.trafficCache.set(edgeId, state);
        this.roadGraph.updateEdgeWeight(edgeId, effectiveWeight, density, avgSpeed);
      }

      if (result.rows.length > 0) {
        // Batch-update effective_weight in DB
        const updates = result.rows.map((row) => {
          const edgeId = Number(row.id);
          const s = this.trafficCache.get(edgeId);
          return s ? `(${edgeId}, ${s.effectiveWeight}, ${s.vehicleDensity}, ${s.averageSpeedKmh})` : null;
        }).filter(Boolean);

        if (updates.length > 0) {
          await this.db.query(
            `UPDATE road_edges AS e
             SET effective_weight = v.ew,
                 vehicle_density  = v.vd,
                 current_speed_kmh = v.cs,
                 updated_at = now()
             FROM (VALUES ${updates.join(',')}) AS v(id, ew, vd, cs)
             WHERE e.id = v.id::bigint`,
          );
        }

        this.logger.debug(`[TRAFFIC] Updated ${result.rows.length} edge weights`);
      }
    } catch (err: unknown) {
      this.logger.warn(`[TRAFFIC] Edge weight update failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  /** Return current traffic state for a set of edge IDs */
  getEdgeTrafficState(edgeIds: number[]): Map<number, TrafficState> {
    const result = new Map<number, TrafficState>();
    for (const id of edgeIds) {
      const s = this.trafficCache.get(id);
      if (s) result.set(id, s);
    }
    return result;
  }

  /** Return a summary of congested edges (density > threshold) */
  async getCongestionSummary(): Promise<{
    congestedEdges: number;
    avgVehicleDensity: number;
    updatedAt: string;
  }> {
    let totalDensity = 0;
    let congestedCount = 0;

    for (const state of this.trafficCache.values()) {
      totalDensity += state.vehicleDensity;
      if (state.vehicleDensity > 0.7) congestedCount++;
    }

    return {
      congestedEdges: congestedCount,
      avgVehicleDensity: this.trafficCache.size > 0 ? totalDensity / this.trafficCache.size : 0,
      updatedAt: new Date().toISOString(),
    };
  }

  /**
   * Detect incidents from recent telemetry patterns (Prompt 26).
   * Signals: sudden braking, speed collapse, vehicle clusters.
   */
  @Cron(CronExpression.EVERY_30_SECONDS)
  async detectIncidents(): Promise<void> {
    try {
      const result = await this.db.queryRead<QueryResultRow>(
        `WITH recent AS (
           SELECT vehicle_id, lat, lng, speed_kmh, heading, h3_index, recorded_at,
                  LAG(speed_kmh) OVER (PARTITION BY vehicle_id ORDER BY recorded_at) AS prev_speed
           FROM vehicle_telemetry
           WHERE recorded_at >= now() - interval '60 seconds'
         ),
         braking AS (
           SELECT vehicle_id, lat, lng, h3_index, speed_kmh, prev_speed,
                  (prev_speed - speed_kmh) AS speed_drop
           FROM recent
           WHERE prev_speed IS NOT NULL AND (prev_speed - speed_kmh) > 15
         ),
         clusters AS (
           SELECT h3_index, COUNT(*) AS vehicle_count,
                  AVG(speed_kmh) AS avg_speed
           FROM recent
           GROUP BY h3_index
           HAVING COUNT(*) >= 5
         )
         SELECT 'sudden_braking' AS incident_type,
                b.lat, b.lng, b.h3_index,
                LEAST(1.0, b.speed_drop / 100.0) AS severity,
                jsonb_build_object('vehicle_id', b.vehicle_id, 'speed_drop', b.speed_drop) AS meta
         FROM braking b
         UNION ALL
         SELECT 'speed_collapse' AS incident_type,
                NULL::float, NULL::float, c.h3_index,
                CASE WHEN c.avg_speed < 10 THEN 0.9 WHEN c.avg_speed < 20 THEN 0.6 ELSE 0.3 END,
                jsonb_build_object('vehicle_count', c.vehicle_count, 'avg_speed', c.avg_speed)
         FROM clusters c WHERE c.avg_speed < 30`,
      );

      for (const row of result.rows) {
        const h3Index = String(row.h3_index);
        // Check if this incident type already active in this cell
        const existing = await this.db.queryRead<QueryResultRow>(
          `SELECT id FROM traffic_incidents
           WHERE h3_index = $1 AND incident_type = $2 AND is_active = TRUE
             AND detected_at >= now() - interval '5 minutes'
           LIMIT 1`,
          [h3Index, row.incident_type],
        );

        if (existing.rows.length === 0) {
          const lat = row.lat ?? h3.cellToLatLng(h3Index)[0];
          const lng = row.lng ?? h3.cellToLatLng(h3Index)[1];

          await this.db.query(
            `INSERT INTO traffic_incidents
               (incident_type, severity, h3_index, geom, metadata)
             VALUES ($1, $2, $3,
               ST_SetSRID(ST_MakePoint($5, $4), 4326)::geography,
               $6)`,
            [row.incident_type, Number(row.severity), h3Index, lat, lng, row.meta ?? {}],
          );
          this.logger.debug(`[INCIDENT] detected type=${row.incident_type} h3=${h3Index}`);
        }
      }
    } catch (err: unknown) {
      this.logger.warn(`[INCIDENT] Detection failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  /**
   * Generate short-term traffic forecasts: 5, 15, 30 minutes (Prompt 18).
   * Uses exponential smoothing over historical and current state.
   */
  async getTrafficForecast(edgeIds: number[]): Promise<TrafficForecast[]> {
    if (edgeIds.length === 0) return [];

    const result = await this.db.queryRead<QueryResultRow>(
      `SELECT ht.edge_id,
              re.h3_partition AS h3_index,
              ht.avg_speed_kmh,
              ht.congestion_frequency,
              re.vehicle_density AS current_density,
              re.current_speed_kmh
       FROM historical_traffic ht
       JOIN road_edges re ON re.id = ht.edge_id
       WHERE ht.edge_id = ANY($1)
         AND ht.hour_of_day = EXTRACT(HOUR FROM now())::int
         AND ht.day_of_week = EXTRACT(DOW FROM now())::int`,
      [edgeIds],
    );

    return result.rows.map((row) => {
      const histSpeed = Number(row.avg_speed_kmh);
      const currentSpeed = row.current_speed_kmh !== null ? Number(row.current_speed_kmh) : histSpeed;
      const alpha = 0.6; // live data weight

      const blended = alpha * currentSpeed + (1 - alpha) * histSpeed;
      const decay5m = 0.95;
      const decay15m = 0.85;
      const decay30m = 0.70;

      return {
        edgeId: Number(row.edge_id),
        h3Index: String(row.h3_index),
        forecast5m: Math.max(5, blended * decay5m),
        forecast15m: Math.max(5, blended * decay15m),
        forecast30m: Math.max(5, blended * decay30m),
        generatedAt: new Date().toISOString(),
      };
    });
  }

  /**
   * Update historical traffic tables after recording a trip (Prompt 16).
   * Called after route completion or from telemetry aggregation.
   */
  async recordHistoricalTraffic(edgeId: number, speedKmh: number): Promise<void> {
    const now = new Date();
    const hour = now.getUTCHours();
    const dow = now.getUTCDay();

    await this.db.query(
      `INSERT INTO historical_traffic (edge_id, hour_of_day, day_of_week, avg_speed_kmh, sample_count)
       VALUES ($1, $2, $3, $4, 1)
       ON CONFLICT (edge_id, hour_of_day, day_of_week) DO UPDATE SET
         avg_speed_kmh = (historical_traffic.avg_speed_kmh * historical_traffic.sample_count + $4)
                          / (historical_traffic.sample_count + 1),
         sample_count  = historical_traffic.sample_count + 1,
         updated_at    = now()`,
      [edgeId, hour, dow, speedKmh],
    );
  }

  /**
   * Predict road hazards from historical patterns (Prompt 27).
   * Returns active hazard H3 cells.
   */
  async getActiveHazards(): Promise<Array<{ h3Index: string; hazardType: string; probability: number }>> {
    const result = await this.db.queryRead<QueryResultRow>(
      `SELECT h3_index, hazard_type, probability
       FROM road_hazards
       WHERE (valid_until IS NULL OR valid_until > now())
         AND valid_from <= now()
       ORDER BY probability DESC`,
    );

    return result.rows.map((row) => ({
      h3Index: String(row.h3_index),
      hazardType: String(row.hazard_type),
      probability: Number(row.probability),
    }));
  }

  /** Return active traffic incidents */
  async getActiveIncidents(): Promise<Array<{
    id: string;
    type: string;
    severity: number;
    h3Index: string;
    detectedAt: string;
  }>> {
    const result = await this.db.queryRead<QueryResultRow>(
      `SELECT id, incident_type, severity, h3_index, detected_at
       FROM traffic_incidents
       WHERE is_active = TRUE
       ORDER BY detected_at DESC
       LIMIT 200`,
    );

    return result.rows.map((row) => ({
      id: String(row.id),
      type: String(row.incident_type),
      severity: Number(row.severity),
      h3Index: String(row.h3_index),
      detectedAt: String(row.detected_at),
    }));
  }

  /** Purge old telemetry (retention policy) */
  @Cron(CronExpression.EVERY_HOUR)
  async purgeStaleTelemetry(): Promise<void> {
    try {
      await this.db.query(
        `DELETE FROM vehicle_telemetry WHERE recorded_at < now() - interval '24 hours'`,
      );
      await this.db.query(
        `UPDATE traffic_incidents SET is_active = FALSE, resolved_at = now()
         WHERE is_active = TRUE AND detected_at < now() - interval '2 hours'`,
      );
    } catch (err: unknown) {
      this.logger.warn(`[TRAFFIC] Purge failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }
}
