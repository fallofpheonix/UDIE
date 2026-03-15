import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import { DigitalTwinStateStoreService } from './digital-twin-state-store.service';
import { BootstrapCityGridDto } from './dto/bootstrap-city-grid.dto';
import { QueryCellHistoryDto } from './dto/query-cell-history.dto';
import { QueryCityGridDto } from './dto/query-city-grid.dto';
import { UpsertCellStateDto } from './dto/upsert-cell-state.dto';
import { TwinCellState } from './digital-twin.types';

type DigitalTwinRow = QueryResultRow & {
  cell_id: string;
  city_id: string;
  region_id: string;
  center_lat: number;
  center_lng: number;
  road_segments: string[] | null;
  intersection_ids: string[] | null;
};

@Injectable()
export class DigitalTwinService {
  private readonly logger = new Logger(DigitalTwinService.name);
  private readonly maxRiskScore = 0.999999;

  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService,
    private readonly stateStore: DigitalTwinStateStoreService,
  ) {}

  async bootstrapGrid(dto: BootstrapCityGridDto) {
    const cells = this.spatial.getCoveringCells(dto.minLat, dto.minLng, dto.maxLat, dto.maxLng, dto.resolution);
    if (!cells.length) {
      return { cityId: dto.city_id, resolution: dto.resolution, cellCount: 0, regionCount: 0 };
    }

    const cellIds: string[] = [];
    const cityIds: string[] = [];
    const regionIds: string[] = [];
    const resolutions: number[] = [];
    const centerLats: number[] = [];
    const centerLngs: number[] = [];
    const capacities: number[] = [];

    for (const cell of cells) {
      const [centerLat, centerLng] = this.spatial.getCellCenter(cell);
      cellIds.push(this.spatial.toDbIndex(cell));
      cityIds.push(dto.city_id);
      regionIds.push(this.spatial.toDbIndex(this.spatial.getCellParent(cell)));
      resolutions.push(dto.resolution);
      centerLats.push(centerLat);
      centerLngs.push(centerLng);
      capacities.push(250);
    }

    const sourceEdges: string[] = [];
    const targetEdges: string[] = [];
    const distanceKs: number[] = [];
    const directionalBiases: number[] = [];
    const transferCapacities: number[] = [];
    const known = new Set(cells);
    for (const cell of cells) {
      const sourceId = this.spatial.toDbIndex(cell);
      for (const neighbor of this.spatial.getCellNeighbors(cell, 1)) {
        if (neighbor === cell || !known.has(neighbor)) {
          continue;
        }
        sourceEdges.push(sourceId);
        targetEdges.push(this.spatial.toDbIndex(neighbor));
        distanceKs.push(1);
        directionalBiases.push(1);
        transferCapacities.push(120);
      }
    }

    await this.db.withTransaction(async (client) => {
      await client.query(
        `
          INSERT INTO city_grid_cells (
            cell_id, city_id, region_id, resolution, center_lat, center_lng, road_capacity
          )
          SELECT *
          FROM unnest(
            $1::bigint[],
            $2::text[],
            $3::bigint[],
            $4::int[],
            $5::double precision[],
            $6::double precision[],
            $7::double precision[]
          )
          ON CONFLICT (cell_id) DO UPDATE
          SET city_id = EXCLUDED.city_id,
              region_id = EXCLUDED.region_id,
              resolution = EXCLUDED.resolution,
              center_lat = EXCLUDED.center_lat,
              center_lng = EXCLUDED.center_lng,
              road_capacity = EXCLUDED.road_capacity,
              metadata_updated_at = now()
        `,
        [cellIds, cityIds, regionIds, resolutions, centerLats, centerLngs, capacities],
      );

      if (sourceEdges.length > 0) {
        await client.query(
          `
            INSERT INTO city_grid_edges (
              source_cell_id,
              target_cell_id,
              distance_k,
              directional_bias,
              transfer_capacity
            )
            SELECT *
            FROM unnest(
              $1::bigint[],
              $2::bigint[],
              $3::int[],
              $4::double precision[],
              $5::double precision[]
            )
            ON CONFLICT (source_cell_id, target_cell_id) DO UPDATE
            SET distance_k = EXCLUDED.distance_k,
                directional_bias = EXCLUDED.directional_bias,
                transfer_capacity = EXCLUDED.transfer_capacity
          `,
          [sourceEdges, targetEdges, distanceKs, directionalBiases, transferCapacities],
        );
      }
    });

    return {
      cityId: dto.city_id,
      resolution: dto.resolution,
      cellCount: cellIds.length,
      regionCount: new Set(regionIds).size,
    };
  }

  async listCellsForViewport(dto: QueryCityGridDto) {
    const cells = this.spatial.getCoveringCells(dto.minLat, dto.minLng, dto.maxLat, dto.maxLng);
    if (!cells.length) {
      return { cityId: dto.city_id, cells: [] };
    }

    const cellIds = cells.map((cell) => this.spatial.toDbIndex(cell));
    const [result, states] = await Promise.all([
      this.db.queryRead<DigitalTwinRow>(
      `
        SELECT
          (cg.cell_id::h3index)::text AS cell_id,
          cg.city_id,
          cg.region_id::text AS region_id,
          cg.center_lat,
          cg.center_lng,
          ARRAY(SELECT jsonb_array_elements_text(cg.road_segments)) AS road_segments,
          ARRAY(SELECT jsonb_array_elements_text(cg.intersection_ids)) AS intersection_ids
        FROM city_grid_cells cg
        WHERE cg.city_id = $1
          AND cg.cell_id = ANY($2::bigint[])
        ORDER BY cg.cell_id
        LIMIT $3
      `,
      [dto.city_id, cellIds, dto.limit],
    ),
      this.stateStore.getCells(cells),
    ]);

    return {
      cityId: dto.city_id,
      cells: result.rows.map((row) => this.mapRow(row, states.get(row.cell_id) ?? null)),
    };
  }

  async getNeighbors(cellId: string, k = 1) {
    const neighbors = this.spatial
      .getCellNeighbors(cellId, k)
      .map((cell) => this.spatial.toDbIndex(cell));

    const [result, states] = await Promise.all([
      this.db.queryRead<DigitalTwinRow>(
      `
        SELECT
          (cg.cell_id::h3index)::text AS cell_id,
          cg.city_id,
          cg.region_id::text AS region_id,
          cg.center_lat,
          cg.center_lng,
          ARRAY(SELECT jsonb_array_elements_text(cg.road_segments)) AS road_segments,
          ARRAY(SELECT jsonb_array_elements_text(cg.intersection_ids)) AS intersection_ids
        FROM city_grid_cells cg
        WHERE cg.cell_id = ANY($1::bigint[])
      `,
      [neighbors],
    ),
      this.stateStore.getCells(this.spatial.getCellNeighbors(cellId, k)),
    ]);

    return {
      originCell: cellId,
      neighbors: result.rows.map((row) => this.mapRow(row, states.get(row.cell_id) ?? null)),
    };
  }

  async getCellHistory(cellId: string, query: QueryCellHistoryDto) {
    const result = await this.db.queryRead<QueryResultRow>(
      `
        SELECT *
        FROM (
          SELECT
            'snapshot'::text AS source,
            snapshot_at AS timestamp,
            traffic_density,
            average_speed,
            disruption_weight,
            risk_score,
            vehicle_count
          FROM digital_twin_state_snapshots
          WHERE cell_id = ($1::h3index)::bigint
            AND snapshot_at >= COALESCE($2::timestamptz, now() - interval '24 hours')
            AND snapshot_at <= COALESCE($3::timestamptz, now())
          UNION ALL
          SELECT
            'ingest'::text AS source,
            timestamp,
            traffic_density,
            average_speed,
            disruption_weight,
            risk_score,
            vehicle_count
          FROM digital_twin_cell_state_history
          WHERE cell_id = ($1::h3index)::bigint
            AND timestamp >= COALESCE($2::timestamptz, now() - interval '24 hours')
            AND timestamp <= COALESCE($3::timestamptz, now())
        ) timeline
        ORDER BY timestamp DESC
        LIMIT $4
      `,
      [cellId, query.from ?? null, query.to ?? null, query.limit],
    );

    return {
      cellId,
      transitions: result.rows.map((row) => ({
        source: String(row.source),
        timestamp: new Date(String(row.timestamp)).toISOString(),
        trafficDensity: Number(row.traffic_density ?? 0),
        averageSpeed: Number(row.average_speed ?? 0),
        disruptionWeight: Number(row.disruption_weight ?? 0),
        riskScore: Number(row.risk_score ?? 0),
        vehicleCount: Number(row.vehicle_count ?? 0),
      })),
    };
  }

  async getCurrentStateForCoordinate(lat: number, lng: number) {
    const cellId = this.spatial.getH3Index(lat, lng);
    const current = this.stateStore.getState(cellId);
    if (!current) {
      return null;
    }
    return {
      trafficDensity: current.trafficDensity,
      averageSpeed: current.averageSpeed,
      vehicleCount: current.vehicleCount,
      disruptionWeight: current.disruptionWeight,
    };
  }

  async upsertCellState(dto: UpsertCellStateDto) {
    const cellText = this.spatial.getH3Index(dto.lat, dto.lng);
    const cellId = this.spatial.toDbIndex(cellText);
    const regionId = this.spatial.getRegionId(dto.lat, dto.lng);
    const [centerLat, centerLng] = this.spatial.getCellCenter(cellText);
    const timestamp = dto.timestamp ? new Date(dto.timestamp) : new Date();

    return this.db.withTransaction(async (client) => {
      await client.query(
        `
          INSERT INTO city_grid_cells (
            cell_id,
            city_id,
            region_id,
            resolution,
            center_lat,
            center_lng,
            road_segments,
            intersection_ids
          )
          VALUES (
            $1::bigint,
            $2,
            $3::bigint,
            9,
            $4,
            $5,
            to_jsonb(COALESCE($6::text[], ARRAY[]::text[])),
            to_jsonb(COALESCE($7::text[], ARRAY[]::text[]))
          )
          ON CONFLICT (cell_id) DO UPDATE
          SET city_id = EXCLUDED.city_id,
              region_id = EXCLUDED.region_id,
              center_lat = EXCLUDED.center_lat,
              center_lng = EXCLUDED.center_lng,
              metadata_updated_at = now(),
              road_segments = CASE
                WHEN COALESCE(array_length($6::text[], 1), 0) = 0 THEN city_grid_cells.road_segments
                ELSE EXCLUDED.road_segments
              END,
              intersection_ids = CASE
                WHEN COALESCE(array_length($7::text[], 1), 0) = 0 THEN city_grid_cells.intersection_ids
                ELSE EXCLUDED.intersection_ids
              END
        `,
        [
          cellId,
          dto.city_id,
          regionId,
          centerLat,
          centerLng,
          dto.road_segments ?? [],
          dto.intersection_ids ?? [],
        ],
      );

      const risk = await client.query<{ risk_score: number }>(
        `
          SELECT LEAST(GREATEST(COALESCE(weight, 0), 0), $2) AS risk_score
          FROM risk_cells
          WHERE h3_index = $1::bigint
          LIMIT 1
        `,
        [cellId, this.maxRiskScore],
      );

      const riskScore = Math.min(
        this.maxRiskScore,
        Math.max(0, Number(risk.rows[0]?.risk_score ?? 0)),
      );

      await client.query(
        `
          INSERT INTO digital_twin_cell_states (
            cell_id,
            region_id,
            traffic_density,
            average_speed,
            disruption_weight,
            risk_score,
            vehicle_count,
            timestamp
          )
          VALUES ($1::bigint, $2::bigint, $3, $4, $5, $6, $7::int, $8::timestamptz)
          ON CONFLICT (cell_id) DO UPDATE
          SET region_id = EXCLUDED.region_id,
              traffic_density = EXCLUDED.traffic_density,
              average_speed = EXCLUDED.average_speed,
              disruption_weight = EXCLUDED.disruption_weight,
              risk_score = EXCLUDED.risk_score,
              vehicle_count = EXCLUDED.vehicle_count,
              timestamp = EXCLUDED.timestamp,
              updated_at = now()
        `,
        [
          cellId,
          regionId,
          dto.traffic_density,
          dto.average_speed,
          dto.disruption_weight,
          riskScore,
          Math.trunc(dto.vehicle_count),
          timestamp.toISOString(),
        ],
      );

      await client.query(
        `
          INSERT INTO digital_twin_cell_state_history (
            cell_id,
            region_id,
            traffic_density,
            average_speed,
            disruption_weight,
            risk_score,
            vehicle_count,
            timestamp
          )
          VALUES ($1::bigint, $2::bigint, $3, $4, $5, $6, $7::int, $8::timestamptz)
        `,
        [
          cellId,
          regionId,
          dto.traffic_density,
          dto.average_speed,
          dto.disruption_weight,
          riskScore,
          Math.trunc(dto.vehicle_count),
          timestamp.toISOString(),
        ],
      );

      const current = await client.query<DigitalTwinRow>(
        `
          SELECT
            (cg.cell_id::h3index)::text AS cell_id,
            cg.city_id,
            cg.region_id::text AS region_id,
            cg.center_lat,
            cg.center_lng,
            ARRAY(SELECT jsonb_array_elements_text(cg.road_segments)) AS road_segments,
            ARRAY(SELECT jsonb_array_elements_text(cg.intersection_ids)) AS intersection_ids
          FROM city_grid_cells cg
          WHERE cg.cell_id = $1::bigint
          LIMIT 1
        `,
        [cellId],
      );
      const state: TwinCellState = {
        cellId: cellText,
        regionId,
        trafficDensity: dto.traffic_density,
        averageSpeed: dto.average_speed,
        disruptionWeight: dto.disruption_weight,
        riskScore,
        vehicleCount: Math.trunc(dto.vehicle_count),
        timestamp: timestamp.toISOString(),
      };
      await this.stateStore.upsert(state);

      return this.mapRow(current.rows[0], state);
    });
  }

  @Cron('*/30 * * * * *')
  async syncRiskSurface() {
    try {
      const updated = await this.db.query<QueryResultRow>(
        `
          UPDATE digital_twin_cell_states ds
          SET risk_score = LEAST(
                GREATEST(
                  COALESCE(
                    (SELECT rc.weight FROM risk_cells rc WHERE rc.h3_index = ds.cell_id LIMIT 1),
                    0
                  ),
                  0
                ),
                $1
              ),
              updated_at = now()
          WHERE ds.timestamp >= now() - interval '6 hours'
          RETURNING
            (ds.cell_id::h3index)::text AS cell_id,
            ds.region_id::text AS region_id,
            ds.traffic_density,
            ds.average_speed,
            ds.disruption_weight,
            ds.risk_score,
            ds.vehicle_count,
            ds.timestamp
        `,
        [this.maxRiskScore],
      );
      await this.stateStore.upsertMany(updated.rows.map((row) => ({
        cellId: String(row.cell_id),
        regionId: String(row.region_id),
        trafficDensity: Number(row.traffic_density ?? 0),
        averageSpeed: Number(row.average_speed ?? 0),
        disruptionWeight: Number(row.disruption_weight ?? 0),
        riskScore: Number(row.risk_score ?? 0),
        vehicleCount: Number(row.vehicle_count ?? 0),
        timestamp: row.timestamp ? new Date(String(row.timestamp)).toISOString() : null,
      })));
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown';
      this.logger.warn(`digital twin risk sync skipped: ${message}`);
    }
  }

  private mapRow(row: DigitalTwinRow | undefined, state: TwinCellState | null) {
    if (!row) {
      return null;
    }

    return {
      cellId: row.cell_id,
      cityId: row.city_id,
      regionId: row.region_id,
      center: {
        lat: Number(row.center_lat),
        lng: Number(row.center_lng),
      },
      roadSegments: row.road_segments ?? [],
      intersectionIds: row.intersection_ids ?? [],
      state: {
        trafficDensity: Number(state?.trafficDensity ?? 0),
        averageSpeed: Number(state?.averageSpeed ?? 0),
        disruptionWeight: Number(state?.disruptionWeight ?? 0),
        riskScore: Number(state?.riskScore ?? 0),
        vehicleCount: Number(state?.vehicleCount ?? 0),
        timestamp: state?.timestamp ?? null,
      },
    };
  }
}
