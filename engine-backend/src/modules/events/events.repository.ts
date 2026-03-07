import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { QueryEventsDto } from './dto/query-events.dto';
import { GeoEventEntity } from './entities/geo-event.entity';
import { CreateEventDto } from './dto/create-event.dto';
import { SpatialService } from '../common/spatial.service';
import * as h3 from 'h3-js';

@Injectable()
export class EventsRepository {
  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService
  ) { }

  async findByBoundingBox(query: QueryEventsDto): Promise<GeoEventEntity[]> {
    const minLng = Number(query.minLng);
    const minLat = Number(query.minLat);
    const maxLng = Number(query.maxLng);
    const maxLat = Number(query.maxLat);
    const minSeverity = query.minSeverity ? Number(query.minSeverity) : undefined;
    const regionId = query.regionId?.trim();
    const limit = query.limit || 100;
    const offset = query.offset || 0;
    const includeSimulation = query.includeSimulation; // Assuming includeSimulation is part of QueryEventsDto

    const values: unknown[] = [minLng, minLat, maxLng, maxLat];

    const tableName = includeSimulation ? 'simulation_events' : 'regional_geo_events_v';
    const statusFilter = includeSimulation ? "'SIMULATION'" : "'ACTIVE'";
    const identityColumn = includeSimulation ? 'id' : 'event_id';

    // We query the versioned regional table or simulation table. 
    // Law 5: No mutations, query only the latest immutable version.
    let sql = `
          SELECT DISTINCT ON (${identityColumn})
            ${identityColumn} AS id,
            event_type,
            severity,
            confidence,
            status,
            h3_index::text,
            ST_Y(geom::geometry) AS latitude,
            ST_X(geom::geometry) AS longitude,
            observed_at
          FROM ${tableName}
          WHERE status IN (${statusFilter})
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
      // Automatic Partition Pruning: Calculate parents covering the box
      const parents = this.spatial.getCoveringRegions(minLat, minLng, maxLat, maxLng);
      if (parents.length > 0) {
        values.push(parents);
        sql += ` AND h3_parent::text = ANY($${values.length})`;
      }
    }

    values.push(limit, offset);
    // Order by event_id for DISTINCT ON, then by version DESC for latest
    sql += ` ORDER BY ${identityColumn}, version DESC LIMIT $${values.length - 1} OFFSET $${values.length}`;

    const result = await this.db.queryRead<GeoEventEntity>(sql, values);
    return result.rows;
  }

  async create(dto: CreateEventDto): Promise<{ id: string }> {
    const h3Index = this.spatial.getH3Index(dto.lat, dto.lng);
    const parent = h3.cellToParent(h3Index, 6);

    const sql = `
      INSERT INTO geo_events (
        event_type, 
        severity, 
        confidence, 
        status, 
        h3_index, 
        h3_parent,
        geom,
        observed_at
      )
      VALUES (
        $1, 
        $2, 
        $3, 
        'ACTIVE', 
        $4, 
        $5, 
        ST_SetSRID(ST_MakePoint($6, $7), 4326),
        now()
      )
      RETURNING event_id AS id
    `;

    const values = [
      dto.type.toUpperCase(),
      Math.floor(dto.weight * 5) + 1, // Map 0-1 weight to 1-5 severity
      dto.confidence ?? 1.0,
      h3Index,
      parent,
      dto.lng,
      dto.lat
    ];

    const result = await this.db.query(sql, values);
    return result.rows[0] as { id: string };
  }
}
