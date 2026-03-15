import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { randomUUID } from 'crypto';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import { CreateDisruptionDto } from './dto/create-disruption.dto';

type InfluenceRow = QueryResultRow & {
  cell_id: string;
  influence_weight: number;
  distance_k: number;
};

@Injectable()
export class DisruptionPropagationService {
  private readonly baseLambdaMeters = 250;
  private readonly baseSigmaMeters = 300;

  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService,
  ) {}

  async createDisruption(dto: CreateDisruptionDto) {
    const disruptionId = randomUUID();
    const h3Cell = this.spatial.getH3Index(dto.lat, dto.lng);
    const regionId = this.spatial.getRegionId(dto.lat, dto.lng);
    const durationMinutes = Math.trunc(dto.estimated_duration_minutes);
    const rings = Math.min(4, Math.max(1, Math.ceil(dto.severity / 2)));
    const influences = this.computeInfluenceCells(h3Cell, dto.severity, dto.kernel, rings);

    await this.db.withTransaction(async (client) => {
      await client.query(
        `
          INSERT INTO simulation_disruptions (
            id,
            disruption_type,
            lat,
            lng,
            h3_index,
            region_id,
            start_time,
            severity,
            estimated_duration_minutes,
            affected_roads,
            kernel
          )
          VALUES (
            $1::uuid,
            $2,
            $3,
            $4,
            ($5::h3index)::bigint,
            $6::bigint,
            $7::timestamptz,
            $8::int,
            $9::int,
            to_jsonb($10::text[]),
            $11
          )
        `,
        [
          disruptionId,
          dto.type,
          dto.lat,
          dto.lng,
          h3Cell,
          regionId,
          dto.start_time,
          dto.severity,
          durationMinutes,
          dto.affected_roads,
          dto.kernel,
        ],
      );

      if (influences.length > 0) {
        await client.query(
          `
            INSERT INTO disruption_influence_cells (
              disruption_id,
              cell_id,
              region_id,
              distance_k,
              influence_weight,
              updated_at
            )
            SELECT
              $1::uuid,
              unnest($2::bigint[]),
              $3::bigint,
              unnest($4::int[]),
              unnest($5::double precision[]),
              now()
          `,
          [
            disruptionId,
            influences.map((entry) => this.spatial.toDbIndex(entry.cellId)),
            regionId,
            influences.map((entry) => entry.distanceK),
            influences.map((entry) => entry.influenceWeight),
          ],
        );
      }
    });

    return {
      id: disruptionId,
      type: dto.type,
      regionId,
      h3Cell,
      propagatedCells: influences.length,
    };
  }

  async listInfluence(disruptionId: string) {
    const result = await this.db.queryRead<InfluenceRow>(
      `
        SELECT
          (cell_id::h3index)::text AS cell_id,
          influence_weight,
          distance_k
        FROM disruption_influence_cells
        WHERE disruption_id = $1::uuid
        ORDER BY influence_weight DESC, distance_k ASC
      `,
      [disruptionId],
    );

    return {
      disruptionId,
      cells: result.rows.map((row) => ({
        cellId: row.cell_id,
        influenceWeight: Number(row.influence_weight),
        distanceK: Number(row.distance_k),
      })),
    };
  }

  private computeInfluenceCells(originCell: string, severity: number, kernel: string, rings: number) {
    const baseWeight = Math.min(0.95, severity / 5);
    const cells = [];

    for (const cell of this.spatial.getInfluenceNeighbors(originCell, rings)) {
      const distanceK = this.spatial.getGridDistance(originCell, cell);
      const distanceMeters = distanceK * 300;
      const influenceWeight = kernel === 'GAUSSIAN'
        ? baseWeight * Math.exp(-(distanceMeters ** 2) / (2 * (this.baseSigmaMeters ** 2)))
        : baseWeight * Math.exp(-distanceMeters / this.baseLambdaMeters);

      if (influenceWeight < 0.001) {
        continue;
      }

      cells.push({
        cellId: cell,
        distanceK,
        influenceWeight: Number(influenceWeight.toFixed(6)),
      });
    }

    return cells;
  }
}
