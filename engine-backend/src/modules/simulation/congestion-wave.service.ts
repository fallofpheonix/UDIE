import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import { EstimateImpactRadiusDto } from './dto/estimate-impact-radius.dto';
import { SimulateCongestionWaveDto } from './dto/simulate-congestion-wave.dto';

type CellStateRow = QueryResultRow & {
  cell_id: string;
  region_id: string;
  road_capacity: number;
  traffic_density: number;
  average_speed: number;
  disruption_weight: number;
  risk_score: number;
  vehicle_count: number;
};

type EdgeRow = QueryResultRow & {
  source_cell_id: string;
  target_cell_id: string;
  directional_bias: number;
  transfer_capacity: number;
};

type WaveCellState = {
  cellId: string;
  regionId: string;
  roadCapacity: number;
  trafficDensity: number;
  averageSpeed: number;
  disruptionWeight: number;
  riskScore: number;
  vehicleCount: number;
  slowdown: number;
};

@Injectable()
export class CongestionWaveService {
  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService,
  ) {}

  async simulate(dto: SimulateCongestionWaveDto) {
    const originCell = this.spatial.getH3Index(dto.lat, dto.lng);
    const cells = this.spatial.getInfluenceNeighbors(originCell, Math.min(4, dto.horizonSteps + 1));
    const [stateRows, edgeRows] = await Promise.all([
      this.loadStates(cells),
      this.loadEdges(cells),
    ]);

    const states = new Map<string, WaveCellState>(stateRows.map((row) => [row.cell_id, {
      cellId: row.cell_id,
      regionId: row.region_id,
      roadCapacity: Number(row.road_capacity ?? 250),
      trafficDensity: Number(row.traffic_density ?? 0),
      averageSpeed: Number(row.average_speed ?? 0),
      disruptionWeight: Number(row.disruption_weight ?? 0),
      riskScore: Number(row.risk_score ?? 0),
      vehicleCount: Number(row.vehicle_count ?? 0),
      slowdown: 0,
    }]));
    const outgoing = this.groupEdges(edgeRows);

    const steps = [];
    let current = new Map<string, WaveCellState>(states);

    for (let step = 1; step <= dto.horizonSteps; step += 1) {
      const next = new Map<string, WaveCellState>();
      const inflow = new Map<string, number>();
      const outflow = new Map<string, number>();

      for (const [cellId, state] of current) {
        const edges = outgoing.get(cellId) ?? [];
        const arrivalBoost = cellId === originCell ? dto.arrivalRate : dto.arrivalRate * 0.35;
        let moved = 0;

        for (const edge of edges) {
          const target = current.get(edge.targetCellId);
          if (!target) {
            continue;
          }
          const congestionFactor = Math.min(0.95, (state.trafficDensity + state.disruptionWeight + arrivalBoost) / 2);
          const availableHeadroom = Math.max(0.05, 1 - Math.min(0.9, target.trafficDensity / 1.5));
          const transfer = Math.min(
            edge.transferCapacity,
            state.vehicleCount * congestionFactor * availableHeadroom * edge.directionalBias * 0.18,
          );
          moved += transfer;
          inflow.set(edge.targetCellId, (inflow.get(edge.targetCellId) ?? 0) + transfer);
        }

        outflow.set(cellId, moved);
      }

      for (const [cellId, state] of current) {
        const arrivals = inflow.get(cellId) ?? 0;
        const departures = outflow.get(cellId) ?? 0;
        const arrivalRate = cellId === originCell ? dto.arrivalRate : dto.arrivalRate * 0.25;
        const nextVehicleCount = Math.max(0, state.vehicleCount - departures + arrivals + state.roadCapacity * arrivalRate);
        const nextDensity = Math.min(1.5, Math.max(0, nextVehicleCount / Math.max(state.roadCapacity, 1)));
        const nextSpeed = Math.max(
          0,
          state.averageSpeed * (1 - Math.min(0.85, nextDensity * 0.32 + state.disruptionWeight * 0.18)),
        );
        const slowdown = Math.max(0, state.averageSpeed - nextSpeed);

        next.set(cellId, {
          ...state,
          vehicleCount: nextVehicleCount,
          trafficDensity: nextDensity,
          averageSpeed: nextSpeed,
          slowdown,
        });
      }

      current = next;
      steps.push({
        step,
        cells: Array.from(current.values())
          .sort((a, b) => b.slowdown - a.slowdown)
          .map((state) => ({
            cellId: state.cellId,
            trafficDensity: Number(state.trafficDensity.toFixed(4)),
            averageSpeed: Number(state.averageSpeed.toFixed(2)),
            vehicleCount: Math.round(state.vehicleCount),
            slowdown: Number(state.slowdown.toFixed(2)),
          })),
      });
    }

    return {
      originCell,
      horizonSteps: dto.horizonSteps,
      waveFrontCells: steps.at(-1)?.cells.filter((cell) => cell.slowdown >= 5).map((cell) => cell.cellId) ?? [],
      steps,
    };
  }

  async estimateImpactRadius(dto: EstimateImpactRadiusDto) {
    const originCell = this.spatial.getH3Index(dto.lat, dto.lng);
    const cells = this.spatial.getInfluenceNeighbors(originCell, dto.maxRings);
    const [stateRows, edgeRows] = await Promise.all([
      this.loadStates(cells),
      this.loadEdges(cells),
    ]);

    const roadMultiplier = Math.max(1, Math.min(2, (dto.affectedRoads?.length ?? 0) / 3 + 1));
    const stateByCell = new Map(stateRows.map((row) => [row.cell_id, row]));
    const edgeCounts = new Map();
    for (const edge of edgeRows) {
      edgeCounts.set(edge.source_cell_id, (edgeCounts.get(edge.source_cell_id) ?? 0) + 1);
      edgeCounts.set(edge.target_cell_id, (edgeCounts.get(edge.target_cell_id) ?? 0) + 1);
    }

    const affected = [];
    let maxDistanceK = 0;
    let predictedDelay = 0;
    for (const cell of cells) {
      const state = stateByCell.get(cell);
      const distanceK = this.spatial.getGridDistance(originCell, cell);
      const topology = edgeCounts.get(cell) ?? 1;
      const density = Number(state?.traffic_density ?? dto.trafficDensity);
      const roadCapacity = Number(state?.road_capacity ?? 250);
      const topologyFactor = 1 + Math.min(1.5, topology / 4);
      const impactScore =
        dto.severity *
        (1 + density) *
        topologyFactor *
        roadMultiplier *
        Math.exp(-(distanceK * 300) / 300);

      const delayMinutes = (impactScore * 2.5 * Math.max(1, 300 / Math.max(roadCapacity, 1)));
      if (impactScore < 0.75) {
        continue;
      }

      affected.push({
        cellId: cell,
        distanceK,
        delayMinutes: Number(delayMinutes.toFixed(2)),
      });
      maxDistanceK = Math.max(maxDistanceK, distanceK);
      predictedDelay = Math.max(predictedDelay, delayMinutes);
    }

    return {
      originCell,
      affected_cells: affected.map((entry) => entry.cellId),
      impact_radius: maxDistanceK * 300,
      predicted_delay: Number(predictedDelay.toFixed(2)),
      cells: affected,
    };
  }

  private async loadStates(cells: string[]): Promise<CellStateRow[]> {
    return (await this.db.queryRead<CellStateRow>(
      `
        SELECT
          (ds.cell_id::h3index)::text AS cell_id,
          ds.region_id::text AS region_id,
          cg.road_capacity,
          ds.traffic_density,
          ds.average_speed,
          ds.disruption_weight,
          ds.risk_score,
          ds.vehicle_count
        FROM digital_twin_cell_states ds
        JOIN city_grid_cells cg ON cg.cell_id = ds.cell_id
        WHERE ds.cell_id = ANY($1::bigint[])
      `,
      [cells.map((cell) => this.spatial.toDbIndex(cell))],
    )).rows;
  }

  private async loadEdges(cells: string[]): Promise<EdgeRow[]> {
    return (await this.db.queryRead<EdgeRow>(
      `
        SELECT
          (source_cell_id::h3index)::text AS source_cell_id,
          (target_cell_id::h3index)::text AS target_cell_id,
          directional_bias,
          transfer_capacity
        FROM city_grid_edges
        WHERE source_cell_id = ANY($1::bigint[])
          AND target_cell_id = ANY($1::bigint[])
      `,
      [cells.map((cell) => this.spatial.toDbIndex(cell))],
    )).rows;
  }

  private groupEdges(edges: EdgeRow[]) {
    const grouped = new Map();
    for (const edge of edges) {
      const bucket = grouped.get(edge.source_cell_id) ?? [];
      bucket.push({
        targetCellId: edge.target_cell_id,
        directionalBias: Number(edge.directional_bias ?? 1),
        transferCapacity: Number(edge.transfer_capacity ?? 0),
      });
      grouped.set(edge.source_cell_id, bucket);
    }
    return grouped;
  }
}
