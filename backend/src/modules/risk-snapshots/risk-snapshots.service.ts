import { Injectable } from '@nestjs/common';
import * as h3 from 'h3-js';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { QueryRiskSnapshotsDto } from './dto/query-risk-snapshots.dto';

@Injectable()
export class RiskSnapshotsService {
  constructor(private readonly db: DatabaseService) {}

  async listSnapshots(query: QueryRiskSnapshotsDto) {
    const cells = this.getBoundingCells(query);
    if (cells.length === 0) {
      return [];
    }

    const result = await this.db.query<QueryResultRow>(
      `SELECT snapshot_time, (h3_index::h3index)::text AS h3_index, risk_weight
       FROM risk_snapshots
       WHERE snapshot_time >= $1::timestamptz
         AND snapshot_time <= $2::timestamptz
         AND h3_index = ANY(
           ARRAY(
             SELECT (cell::h3index)::bigint
             FROM unnest($3::text[]) AS cell
           )
         )
       ORDER BY snapshot_time ASC
       LIMIT $4`,
      [query.start_time, query.end_time, cells, query.limit ?? 10000],
    );

    return result.rows.map((row) => ({
      snapshotTime: row.snapshot_time,
      h3Index: String(row.h3_index),
      riskWeight: Number(row.risk_weight),
    }));
  }

  private getBoundingCells(query: QueryRiskSnapshotsDto): string[] {
    const minLat = Number(query.minLat);
    const maxLat = Number(query.maxLat);
    const minLng = Number(query.minLng);
    const maxLng = Number(query.maxLng);

    const polygonCoordinates: number[][] = [
      [minLat, minLng],
      [maxLat, minLng],
      [maxLat, maxLng],
      [minLat, maxLng],
      [minLat, minLng],
    ];
    return h3.polygonToCells(polygonCoordinates, 9, false);
  }
}
