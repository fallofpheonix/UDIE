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
    const city = query.city?.trim();

    const values: unknown[] = [minLng, minLat, maxLng, maxLat];
    let sql = `
      SELECT
        id,
        event_type,
        severity,
        confidence,
        status,
        source_id,
        description,
        observed_at,
        expires_at,
        last_observed,
        h3_index,
        ST_Y(geom::geometry) AS latitude,
        ST_X(geom::geometry) AS longitude
      FROM active_geo_events
      WHERE ST_Intersects(
        geom::geometry,
        ST_MakeEnvelope($1, $2, $3, $4, 4326)
      )
    `;

    if (city) {
      values.push(city);
      sql += ` AND city_code = $${values.length}`;
    }

    if (minSeverity !== undefined && !Number.isNaN(minSeverity)) {
      values.push(minSeverity);
      sql += ` AND severity >= $${values.length}`;
    }

    if (query.eventTypes) {
      const eventTypes = query.eventTypes.split(',').map((value) => value.trim().toUpperCase());
      values.push(eventTypes);
      sql += ` AND event_type::text = ANY($${values.length})`;
    }

    sql += ' ORDER BY confidence DESC, severity DESC LIMIT 2000';

    const result = await this.db.query<GeoEventEntity>(sql, values);
    return result.rows;
  }
}
