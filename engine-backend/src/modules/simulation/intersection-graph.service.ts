import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { BuildIntersectionGraphDto } from './dto/build-intersection-graph.dto';

type GraphEdgeRow = QueryResultRow & {
  source_intersection: string;
  target_intersection: string;
  capacity: number;
  length_meters: number;
  speed_limit: number;
};

@Injectable()
export class IntersectionGraphService {
  constructor(private readonly db: DatabaseService) {}

  async buildGraph(dto: BuildIntersectionGraphDto) {
    const result = await this.db.query<GraphEdgeRow>(
      `
        WITH intersection_cells AS (
          SELECT
            jsonb_array_elements_text(cg.intersection_ids) AS intersection_id,
            cg.cell_id,
            cg.city_id,
            cg.region_id,
            COALESCE(cg.road_capacity, 250) AS road_capacity
          FROM city_grid_cells cg
          WHERE cg.intersection_ids <> '[]'::jsonb
            AND ($1::text IS NULL OR cg.city_id = $1)
        ),
        linked AS (
          SELECT
            src.intersection_id AS source_intersection,
            dst.intersection_id AS target_intersection,
            MIN(src.city_id) AS city_id,
            MIN(src.region_id) AS region_id,
            AVG((src.road_capacity + dst.road_capacity) / 2.0) AS capacity,
            AVG(edge.distance_k * 300.0) AS length_meters,
            AVG(COALESCE(ds.average_speed, 40)) AS speed_limit
          FROM city_grid_edges edge
          JOIN intersection_cells src ON src.cell_id = edge.source_cell_id
          JOIN intersection_cells dst ON dst.cell_id = edge.target_cell_id
          LEFT JOIN digital_twin_cell_states ds ON ds.cell_id = edge.source_cell_id
          WHERE src.intersection_id <> dst.intersection_id
          GROUP BY src.intersection_id, dst.intersection_id
        )
        INSERT INTO intersection_graph_edges (
          source_intersection_id,
          target_intersection_id,
          city_id,
          region_id,
          capacity,
          length_meters,
          speed_limit
        )
        SELECT
          source_intersection,
          target_intersection,
          city_id,
          region_id::bigint,
          capacity,
          length_meters,
          GREATEST(20, speed_limit)
        FROM linked
        ON CONFLICT (source_intersection_id, target_intersection_id) DO UPDATE
        SET city_id = EXCLUDED.city_id,
            region_id = EXCLUDED.region_id,
            capacity = EXCLUDED.capacity,
            length_meters = EXCLUDED.length_meters,
            speed_limit = EXCLUDED.speed_limit,
            updated_at = now()
        RETURNING
          source_intersection_id AS source_intersection,
          target_intersection_id AS target_intersection,
          capacity,
          length_meters,
          speed_limit
      `,
      [dto.city_id ?? null],
    );

    return {
      cityId: dto.city_id ?? null,
      edgeCount: result.rows.length,
      edges: result.rows.map((row) => ({
        sourceIntersection: row.source_intersection,
        targetIntersection: row.target_intersection,
        capacity: Number(row.capacity ?? 0),
        lengthMeters: Number(row.length_meters ?? 0),
        speedLimit: Number(row.speed_limit ?? 0),
      })),
    };
  }

  async getGraph(cityId?: string) {
    const result = await this.db.queryRead<GraphEdgeRow>(
      `
        SELECT
          source_intersection_id AS source_intersection,
          target_intersection_id AS target_intersection,
          capacity,
          length_meters,
          speed_limit
        FROM intersection_graph_edges
        WHERE ($1::text IS NULL OR city_id = $1)
        ORDER BY source_intersection_id, target_intersection_id
      `,
      [cityId ?? null],
    );

    return {
      cityId: cityId ?? null,
      edgeCount: result.rows.length,
      edges: result.rows.map((row) => ({
        sourceIntersection: row.source_intersection,
        targetIntersection: row.target_intersection,
        capacity: Number(row.capacity ?? 0),
        lengthMeters: Number(row.length_meters ?? 0),
        speedLimit: Number(row.speed_limit ?? 0),
      })),
    };
  }
}
