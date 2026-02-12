import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { QueryEventsDto } from './dto/query-events.dto';
import { GeoEventEntity } from './entities/geo-event.entity';

@Injectable()
export class EventsRepository {
  constructor(private readonly db: DatabaseService) {}

  async findByBoundingBox(query: QueryEventsDto): Promise<GeoEventEntity[]> {
    const values: unknown[] = [query.minLng, query.minLat, query.maxLng, query.maxLat];
    let sql = `
      SELECT
        id,
        event_type::text,
        severity,
        confidence,
        source::text,
        description,
        start_time,
        end_time,
        ST_Y(geom::geometry) AS latitude,
        ST_X(geom::geometry) AS longitude
      FROM active_geo_events
      WHERE ST_Intersects(
        geom::geometry,
        ST_MakeEnvelope($1, $2, $3, $4, 4326)
      )
    `;

    if (query.minSeverity !== undefined) {
      values.push(query.minSeverity);
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
