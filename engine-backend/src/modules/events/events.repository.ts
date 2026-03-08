import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { PartitionManagementService } from '../database/partition-management.service';
import { SpatialService } from '../common/spatial.service';
import { CreateEventDto } from './dto/create-event.dto';
import { QueryEventsDto } from './dto/query-events.dto';
import { GeoEventEntity } from './entities/geo-event.entity';

@Injectable()
export class EventsRepository {
  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService,
    private readonly partitionManager: PartitionManagementService,
  ) {}

  async findByBoundingBox(query: QueryEventsDto): Promise<GeoEventEntity[]> {
    const minLng = Number(query.minLng);
    const minLat = Number(query.minLat);
    const maxLng = Number(query.maxLng);
    const maxLat = Number(query.maxLat);
    const minSeverity = query.minSeverity ? Number(query.minSeverity) : undefined;
    const regionId = query.regionId?.trim();
    const limit = query.limit || 100;
    const offset = query.offset || 0;
    const includeSimulation = query.includeSimulation;

    const values: unknown[] = [minLng, minLat, maxLng, maxLat];

    if (includeSimulation) {
      let simulationSql = `
        SELECT
          id::text AS id,
          event_type,
          severity,
          1.0::double precision AS confidence,
          'SIMULATION'::text AS status,
          NULL::text AS h3_index,
          lat AS latitude,
          lng AS longitude,
          created_at AS observed_at
        FROM simulation_events
        WHERE lng BETWEEN $1 AND $3
          AND lat BETWEEN $2 AND $4
      `;

      if (minSeverity !== undefined && !Number.isNaN(minSeverity)) {
        values.push(minSeverity);
        simulationSql += ` AND severity >= $${values.length}`;
      }

      if (query.eventTypes) {
        const eventTypes = query.eventTypes.split(',').map((value) => value.trim().toUpperCase());
        values.push(eventTypes);
        simulationSql += ` AND event_type::text = ANY($${values.length})`;
      }

      values.push(limit, offset);
      simulationSql += ` ORDER BY created_at DESC LIMIT $${values.length - 1} OFFSET $${values.length}`;
      const simulationResult = await this.db.queryRead<GeoEventEntity>(simulationSql, values);
      return simulationResult.rows;
    }

    let sql = `
      SELECT DISTINCT ON (event_id)
        event_id AS id,
        event_type,
        severity,
        confidence,
        status,
        h3_index::text,
        ST_Y(geom::geometry) AS latitude,
        ST_X(geom::geometry) AS longitude,
        observed_at
      FROM regional_geo_events_v
      WHERE status = 'ACTIVE'
        AND ST_Intersects(
          geom::geometry,
          ST_MakeEnvelope($1, $2, $3, $4, 4326)
        )
    `;

    if (minSeverity !== undefined && !Number.isNaN(minSeverity)) {
      values.push(minSeverity);
      sql += ` AND severity >= $${values.length}`;
    }

    if (query.eventTypes) {
      const eventTypes = query.eventTypes.split(',').map((value) => value.trim().toUpperCase());
      values.push(eventTypes);
      sql += ` AND event_type::text = ANY($${values.length})`;
    }

    if (regionId) {
      values.push(regionId);
      sql += ` AND h3_parent::text = $${values.length}`;
    } else {
      const parents = this.spatial.getCoveringRegions(minLat, minLng, maxLat, maxLng);
      if (parents.length > 0) {
        values.push(parents);
        sql += ` AND h3_parent::text = ANY($${values.length})`;
      }
    }

    values.push(limit, offset);
    sql += ` ORDER BY event_id, version DESC LIMIT $${values.length - 1} OFFSET $${values.length}`;

    const result = await this.db.queryRead<GeoEventEntity>(sql, values);
    return result.rows;
  }

  async create(dto: CreateEventDto): Promise<{ id: string }> {
    const h3Index = this.spatial.getH3Index(dto.lat, dto.lng);
    const h3IndexDb = BigInt(`0x${h3Index}`).toString(10);
    const h3Parent = this.spatial.getRegionId(dto.lat, dto.lng);
    const severity = Math.max(1, Math.min(5, Math.floor(dto.weight * 5) + 1));
    const observedAt = new Date().toISOString();

    await this.partitionManager.ensurePartition(h3Parent);

    const sql = `
      INSERT INTO regional_geo_events_v (
        event_id,
        version,
        h3_parent,
        h3_index,
        event_type,
        severity,
        confidence,
        geom,
        status,
        observed_at
      )
      VALUES (
        gen_random_uuid(),
        1,
        $1,
        $2,
        $3,
        $4,
        $5,
        ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography,
        'ACTIVE',
        $8
      )
      RETURNING event_id AS id
    `;

    const values = [
      h3Parent,
      h3IndexDb,
      dto.type,
      severity,
      dto.confidence ?? 1.0,
      dto.lng,
      dto.lat,
      observedAt,
    ];

    const result = await this.db.query(sql, values);
    return result.rows[0] as { id: string };
  }
}
