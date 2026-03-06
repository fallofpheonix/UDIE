import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { QueryEventsDto } from './dto/query-events.dto';
import { GeoEventEntity } from './entities/geo-event.entity';

@Injectable()
export class EventsRepository {
  constructor(private readonly db: DatabaseService) { }

  async findByBoundingBox(query: QueryEventsDto): Promise<GeoEventEntity[]> {
    const minLng = Number(query.minLng);
    const minLat = Number(query.minLat);
    const maxLng = Number(query.maxLng);
    const maxLat = Number(query.maxLat);
    const minSeverity = query.minSeverity ? Number(query.minSeverity) : undefined;
    const regionId = query.regionId?.trim();
    const limit = query.limit || 100;
    const offset = query.offset || 0;

    const values: unknown[] = [minLng, minLat, maxLng, maxLat];

    // We query the versioned regional table. 
    // Law 5: No mutations, query only the latest immutable version.
    let sql = `
      SELECT DISTINCT ON (event_id)
        event_id as id,
        event_type,
        severity,
        confidence,
        status,
        h3_index::text,
        ST_Y(geom::geometry) AS latitude,
        ST_X(geom::geometry) AS longitude,
        observed_at
      FROM regional_geo_events_v
      WHERE ST_Intersects(
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
    }

    values.push(limit, offset);
    // Order by event_id for DISTINCT ON, then by version DESC for latest
    sql += ` ORDER BY event_id, version DESC LIMIT $${values.length - 1} OFFSET $${values.length}`;

    const result = await this.db.query<GeoEventEntity>(sql, values);
    return result.rows;
  }
}
