import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { DatabaseService } from '../../database/database.service';
import { RouteCacheService } from './route-cache.service';

@Injectable()
export class RoadGraphMaterializationService implements OnModuleInit {
  private readonly logger = new Logger(RoadGraphMaterializationService.name);
  private lastRefreshAt = 0;
  private refreshInFlight: Promise<void> | null = null;

  constructor(
    private readonly db: DatabaseService,
    private readonly routeCache: RouteCacheService,
  ) {}

  async onModuleInit() {
    await this.ensureReady(true).catch((error: unknown) => {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[ROUTING_GRAPH] bootstrap_failed reason=${message}`);
    });
  }

  @Cron('*/30 * * * * *')
  async refreshOnInterval() {
    await this.ensureReady(false).catch((error: unknown) => {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`[ROUTING_GRAPH] refresh_failed reason=${message}`);
    });
  }

  async ensureReady(force: boolean) {
    const now = Date.now();
    if (!force && this.lastRefreshAt > 0 && (now - this.lastRefreshAt) < 25_000) {
      return;
    }
    if (this.refreshInFlight) {
      return this.refreshInFlight;
    }

    this.refreshInFlight = this.refresh(force)
      .finally(() => {
        this.refreshInFlight = null;
      });
    return this.refreshInFlight;
  }

  private async refresh(force: boolean) {
    const advisoryKey = 905_301;
    const lock = await this.db.query<{ locked: boolean }>(
      'SELECT pg_try_advisory_lock($1) AS locked',
      [advisoryKey],
    );
    if (!lock.rows[0]?.locked) {
      return;
    }

    try {
      const shouldRun = force || await this.needsRefresh();
      if (!shouldRun) {
        this.lastRefreshAt = Date.now();
        return;
      }

      await this.db.withTransaction(async (client) => {
        await client.query(
          `
            INSERT INTO road_graph_nodes (
              cell_id,
              city_id,
              region_id,
              center_lat,
              center_lng,
              road_segments,
              intersection_ids,
              updated_at
            )
            SELECT
              cg.cell_id,
              cg.city_id,
              cg.region_id,
              cg.center_lat,
              cg.center_lng,
              COALESCE(ARRAY(SELECT jsonb_array_elements_text(cg.road_segments)), '{}'::text[]),
              COALESCE(ARRAY(SELECT jsonb_array_elements_text(cg.intersection_ids)), '{}'::text[]),
              now()
            FROM city_grid_cells cg
            ON CONFLICT (cell_id) DO UPDATE
            SET city_id = EXCLUDED.city_id,
                region_id = EXCLUDED.region_id,
                center_lat = EXCLUDED.center_lat,
                center_lng = EXCLUDED.center_lng,
                road_segments = EXCLUDED.road_segments,
                intersection_ids = EXCLUDED.intersection_ids,
                updated_at = now()
          `,
        );

        await client.query(
          `
            INSERT INTO road_graph_edges (
              source_cell_id,
              target_cell_id,
              city_id,
              region_id,
              length_meters,
              lanes,
              speed_limit,
              road_type,
              geometry,
              updated_at
            )
            SELECT
              edge.source_cell_id,
              edge.target_cell_id,
              src.city_id,
              src.region_id,
              GREATEST(edge.distance_k * 300.0, 25.0) AS length_meters,
              GREATEST(
                1,
                LEAST(6, CEIL(((COALESCE(src.road_capacity, 250) + COALESCE(dst.road_capacity, 250)) / 2.0) / 120.0))
              )::int AS lanes,
              GREATEST(
                20,
                LEAST(100, COALESCE((srcState.average_speed + dstState.average_speed) / 2.0, 40))
              ) AS speed_limit,
              CASE
                WHEN ((COALESCE(src.road_capacity, 250) + COALESCE(dst.road_capacity, 250)) / 2.0) >= 500 THEN 'HIGHWAY'
                WHEN ((COALESCE(src.road_capacity, 250) + COALESCE(dst.road_capacity, 250)) / 2.0) >= 300 THEN 'ARTERIAL'
                ELSE 'LOCAL'
              END AS road_type,
              ST_MakeLine(
                ST_SetSRID(ST_MakePoint(src.center_lng, src.center_lat), 4326),
                ST_SetSRID(ST_MakePoint(dst.center_lng, dst.center_lat), 4326)
              )::geometry(LineString, 4326) AS geometry,
              now()
            FROM city_grid_edges edge
            JOIN city_grid_cells src ON src.cell_id = edge.source_cell_id
            JOIN city_grid_cells dst ON dst.cell_id = edge.target_cell_id
            LEFT JOIN digital_twin_cell_states srcState ON srcState.cell_id = edge.source_cell_id
            LEFT JOIN digital_twin_cell_states dstState ON dstState.cell_id = edge.target_cell_id
            ON CONFLICT (source_cell_id, target_cell_id) DO UPDATE
            SET city_id = EXCLUDED.city_id,
                region_id = EXCLUDED.region_id,
                length_meters = EXCLUDED.length_meters,
                lanes = EXCLUDED.lanes,
                speed_limit = EXCLUDED.speed_limit,
                road_type = EXCLUDED.road_type,
                geometry = EXCLUDED.geometry,
                updated_at = now()
          `,
        );

        await client.query(
          `
            WITH hazard_cells AS (
              SELECT cell_id, event_type, event_count
              FROM (
                SELECT
                  h3_index::bigint AS cell_id,
                  event_type,
                  COUNT(*)::int AS event_count,
                  ROW_NUMBER() OVER (
                    PARTITION BY h3_index::bigint
                    ORDER BY COUNT(*) DESC, event_type
                  ) AS rn
                FROM regional_geo_events_v
                WHERE observed_at >= now() - interval '6 hours'
                GROUP BY h3_index::bigint, event_type
              ) ranked
              WHERE rn = 1
            )
            INSERT INTO routing_edge_weights (
              source_cell_id,
              target_cell_id,
              city_id,
              region_id,
              distance_meters,
              base_travel_time_sec,
              current_speed_kmh,
              traffic_density,
              disruption_weight,
              risk_score,
              road_capacity,
              lanes,
              speed_limit,
              road_type,
              dominant_hazard,
              hazard_count,
              edge_cost,
              updated_at
            )
            SELECT
              edge.source_cell_id,
              edge.target_cell_id,
              edge.city_id,
              edge.region_id,
              edge.length_meters,
              edge.length_meters / GREATEST(edge.speed_limit, 5) * 3.6 AS base_travel_time_sec,
              GREATEST(
                5,
                LEAST(
                  edge.speed_limit,
                  COALESCE((srcState.average_speed + dstState.average_speed) / 2.0, edge.speed_limit)
                )
              ) AS current_speed_kmh,
              GREATEST(
                COALESCE(srcState.traffic_density, 0),
                COALESCE(dstState.traffic_density, 0)
              ) AS traffic_density,
              GREATEST(
                COALESCE(srcState.disruption_weight, 0),
                COALESCE(dstState.disruption_weight, 0)
              ) AS disruption_weight,
              LEAST(
                0.999999,
                GREATEST(
                  COALESCE(srcRisk.weight, 0),
                  COALESCE(dstRisk.weight, 0)
                )
              ) AS risk_score,
              GREATEST(
                1,
                (COALESCE(srcCell.road_capacity, 250) + COALESCE(dstCell.road_capacity, 250)) / 2.0
              ) AS road_capacity,
              edge.lanes,
              edge.speed_limit,
              edge.road_type,
              COALESCE(srcHazard.event_type, dstHazard.event_type) AS dominant_hazard,
              GREATEST(COALESCE(srcHazard.event_count, 0), COALESCE(dstHazard.event_count, 0)) AS hazard_count,
              (
                (edge.length_meters / GREATEST(
                  5,
                  LEAST(
                    edge.speed_limit,
                    COALESCE((srcState.average_speed + dstState.average_speed) / 2.0, edge.speed_limit)
                  )
                ) * 3.6) *
                (
                  1
                  + (GREATEST(COALESCE(srcState.traffic_density, 0), COALESCE(dstState.traffic_density, 0)) * 1.4)
                  + (GREATEST(COALESCE(srcState.disruption_weight, 0), COALESCE(dstState.disruption_weight, 0)) * 0.9)
                  + (LEAST(0.999999, GREATEST(COALESCE(srcRisk.weight, 0), COALESCE(dstRisk.weight, 0))) * 2.3)
                  + LEAST(0.8, 180.0 / GREATEST((COALESCE(srcCell.road_capacity, 250) + COALESCE(dstCell.road_capacity, 250)) / 2.0, 1))
                )
              ) AS edge_cost,
              now()
            FROM road_graph_edges edge
            JOIN city_grid_cells srcCell ON srcCell.cell_id = edge.source_cell_id
            JOIN city_grid_cells dstCell ON dstCell.cell_id = edge.target_cell_id
            LEFT JOIN digital_twin_cell_states srcState ON srcState.cell_id = edge.source_cell_id
            LEFT JOIN digital_twin_cell_states dstState ON dstState.cell_id = edge.target_cell_id
            LEFT JOIN risk_cells srcRisk ON srcRisk.h3_index = edge.source_cell_id
            LEFT JOIN risk_cells dstRisk ON dstRisk.h3_index = edge.target_cell_id
            LEFT JOIN hazard_cells srcHazard ON srcHazard.cell_id = edge.source_cell_id
            LEFT JOIN hazard_cells dstHazard ON dstHazard.cell_id = edge.target_cell_id
            ON CONFLICT (source_cell_id, target_cell_id) DO UPDATE
            SET city_id = EXCLUDED.city_id,
                region_id = EXCLUDED.region_id,
                distance_meters = EXCLUDED.distance_meters,
                base_travel_time_sec = EXCLUDED.base_travel_time_sec,
                current_speed_kmh = EXCLUDED.current_speed_kmh,
                traffic_density = EXCLUDED.traffic_density,
                disruption_weight = EXCLUDED.disruption_weight,
                risk_score = EXCLUDED.risk_score,
                road_capacity = EXCLUDED.road_capacity,
                lanes = EXCLUDED.lanes,
                speed_limit = EXCLUDED.speed_limit,
                road_type = EXCLUDED.road_type,
                dominant_hazard = EXCLUDED.dominant_hazard,
                hazard_count = EXCLUDED.hazard_count,
                edge_cost = EXCLUDED.edge_cost,
                updated_at = now()
          `,
        );

        await client.query(
          `
            INSERT INTO historical_traffic_edges (
              source_cell_id,
              target_cell_id,
              day_of_week,
              hour_of_day,
              avg_speed_kmh,
              congestion_frequency,
              incident_frequency,
              sample_count,
              updated_at
            )
            SELECT
              edge.source_cell_id,
              edge.target_cell_id,
              EXTRACT(DOW FROM sample.observed_at)::smallint AS day_of_week,
              EXTRACT(HOUR FROM sample.observed_at)::smallint AS hour_of_day,
              AVG(sample.average_speed) AS avg_speed_kmh,
              AVG(sample.traffic_density) AS congestion_frequency,
              COALESCE(alerts.incident_frequency, 0) AS incident_frequency,
              COUNT(*)::int AS sample_count,
              now()
            FROM city_grid_edges edge
            JOIN digital_twin_traffic_samples sample ON sample.cell_id = edge.source_cell_id
            LEFT JOIN (
              SELECT
                cell_id,
                EXTRACT(DOW FROM detected_at)::smallint AS day_of_week,
                EXTRACT(HOUR FROM detected_at)::smallint AS hour_of_day,
                COUNT(*)::double precision AS incident_frequency
              FROM digital_twin_state_alerts
              GROUP BY cell_id, EXTRACT(DOW FROM detected_at), EXTRACT(HOUR FROM detected_at)
            ) alerts
              ON alerts.cell_id = edge.source_cell_id
             AND alerts.day_of_week = EXTRACT(DOW FROM sample.observed_at)::smallint
             AND alerts.hour_of_day = EXTRACT(HOUR FROM sample.observed_at)::smallint
            WHERE sample.observed_at >= now() - interval '30 days'
            GROUP BY
              edge.source_cell_id,
              edge.target_cell_id,
              EXTRACT(DOW FROM sample.observed_at),
              EXTRACT(HOUR FROM sample.observed_at),
              alerts.incident_frequency
            ON CONFLICT (source_cell_id, target_cell_id, day_of_week, hour_of_day) DO UPDATE
            SET avg_speed_kmh = EXCLUDED.avg_speed_kmh,
                congestion_frequency = EXCLUDED.congestion_frequency,
                incident_frequency = EXCLUDED.incident_frequency,
                sample_count = EXCLUDED.sample_count,
                updated_at = now()
          `,
        );
      });

      this.lastRefreshAt = Date.now();
      await this.routeCache.invalidateAll();
    } finally {
      await this.db.query('SELECT pg_advisory_unlock($1)', [advisoryKey]).catch(() => undefined);
    }
  }

  private async needsRefresh() {
    const result = await this.db.queryRead<{ stale: boolean }>(
      `
        SELECT EXISTS (
          SELECT 1
          FROM routing_edge_weights
          WHERE updated_at < now() - interval '45 seconds'
        ) OR NOT EXISTS (
          SELECT 1 FROM routing_edge_weights
        ) AS stale
      `,
    );

    return result.rows[0]?.stale ?? true;
  }
}
