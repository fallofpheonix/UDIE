import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import { QueryNationalViewportDto } from './dto/query-national-viewport.dto';
import { RegisterNationalRegionDto } from './dto/register-national-region.dto';

type NationalSummaryRow = QueryResultRow & {
  region_id: string | number | bigint;
  traffic_density: number;
  average_speed: number;
  risk_level: number;
  cell_count: number;
};

@Injectable()
export class NationwideDigitalTwinService {
  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService,
  ) {}

  async registerRegion(dto: RegisterNationalRegionDto) {
    await this.db.query(
      `
        INSERT INTO national_region_registry (
          region_id,
          region_name,
          cluster_endpoint,
          city_id,
          min_lat,
          min_lng,
          max_lat,
          max_lng
        )
        VALUES ($1::bigint, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (region_id) DO UPDATE
        SET region_name = EXCLUDED.region_name,
            cluster_endpoint = EXCLUDED.cluster_endpoint,
            city_id = EXCLUDED.city_id,
            min_lat = EXCLUDED.min_lat,
            min_lng = EXCLUDED.min_lng,
            max_lat = EXCLUDED.max_lat,
            max_lng = EXCLUDED.max_lng,
            updated_at = now()
      `,
      [
        dto.region_id,
        dto.region_name,
        dto.cluster_endpoint,
        dto.city_id ?? null,
        dto.min_lat,
        dto.min_lng,
        dto.max_lat,
        dto.max_lng,
      ],
    );

    return {
      regionId: dto.region_id,
      clusterEndpoint: dto.cluster_endpoint,
      registered: true,
    };
  }

  async regionalView(query: QueryNationalViewportDto) {
    const regions = this.spatial.getCoveringRegions(query.minLat, query.minLng, query.maxLat, query.maxLng);
    const summary = await this.db.queryRead<NationalSummaryRow>(
      `
        SELECT
          ds.region_id::text AS region_id,
          AVG(ds.traffic_density) AS traffic_density,
          AVG(ds.average_speed) AS average_speed,
          AVG(ds.risk_score) AS risk_level,
          COUNT(*)::int AS cell_count
        FROM digital_twin_cell_states ds
        WHERE ds.region_id = ANY($1::bigint[])
        GROUP BY ds.region_id
        ORDER BY ds.region_id
      `,
      [regions],
    );

    const registry = await this.db.queryRead<QueryResultRow>(
      `
        SELECT region_id::text AS region_id, region_name, cluster_endpoint, city_id
        FROM national_region_registry
        WHERE region_id = ANY($1::bigint[])
      `,
      [regions],
    );
    const registryById = new Map(registry.rows.map((row) => [String(row.region_id), row]));

    return {
      shardResolution: 6,
      regions: summary.rows.map((row) => {
        const meta = registryById.get(String(row.region_id));
        return {
          regionId: String(row.region_id),
          regionName: meta?.region_name ?? null,
          clusterEndpoint: meta?.cluster_endpoint ?? null,
          cityId: meta?.city_id ?? null,
          trafficDensity: Number(row.traffic_density ?? 0),
          averageSpeed: Number(row.average_speed ?? 0),
          riskLevel: Number(row.risk_level ?? 0),
          cellCount: Number(row.cell_count ?? 0),
        };
      }),
    };
  }

  async regionalSystems(query: QueryNationalViewportDto) {
    const regions = this.spatial.getCoveringRegions(query.minLat, query.minLng, query.maxLat, query.maxLng);
    const result = await this.db.queryRead<QueryResultRow>(
      `
        SELECT
          region_id::text AS region_id,
          region_name,
          cluster_endpoint,
          city_id,
          min_lat,
          min_lng,
          max_lat,
          max_lng
        FROM national_region_registry
        WHERE region_id = ANY($1::bigint[])
        ORDER BY region_id
      `,
      [regions],
    );

    return {
      shardResolution: 6,
      systems: result.rows.map((row) => ({
        regionId: String(row.region_id),
        regionName: String(row.region_name),
        clusterEndpoint: String(row.cluster_endpoint),
        cityId: row.city_id ? String(row.city_id) : null,
        bounds: {
          minLat: Number(row.min_lat),
          minLng: Number(row.min_lng),
          maxLat: Number(row.max_lat),
          maxLng: Number(row.max_lng),
        },
      })),
    };
  }
}
