import { Injectable } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { SpatialService } from '../common/spatial.service';
import { DigitalTwinService } from './digital-twin.service';
import { DisruptionPropagationService } from './disruption-propagation.service';
import { EstimateEvacuationDto } from './dto/estimate-evacuation.dto';
import { GenerateRiskSurfaceDto } from './dto/generate-risk-surface.dto';
import { InjectSyntheticEventDto } from './dto/inject-synthetic-event.dto';
import { QuerySimulationResultsDto } from './dto/query-simulation-results.dto';
import { SimulateEventDto } from './dto/simulate-event.dto';
import { SimulateFutureHorizonDto } from './dto/simulate-future-horizon.dto';

type ScenarioCellRow = QueryResultRow & {
  cell_id: string;
  region_id: string;
  center_lat: number;
  center_lng: number;
  road_capacity: number;
  traffic_density: number | null;
  average_speed: number | null;
  disruption_weight: number | null;
  risk_score: number | null;
  vehicle_count: number | null;
  historical_incident_probability: number | null;
  disruption_proximity: number | null;
};

@Injectable()
export class ScenarioSimulationService {
  constructor(
    private readonly db: DatabaseService,
    private readonly spatial: SpatialService,
    private readonly digitalTwin: DigitalTwinService,
    private readonly disruptionPropagation: DisruptionPropagationService,
  ) {}

  async generateRiskSurface(dto: GenerateRiskSurfaceDto) {
    const cells = await this.loadScenarioCells(dto);
    const heatmap = cells.map((cell) => ({
      cellId: cell.cellId,
      center: cell.center,
      trafficDensity: cell.trafficDensity,
      disruptionProximity: cell.disruptionProximity,
      historicalIncidentProbability: cell.historicalIncidentProbability,
      riskScore: this.combineRisk(cell.trafficDensity, cell.disruptionProximity, cell.historicalIncidentProbability, cell.currentRisk),
    }));

    return {
      cityId: dto.city_id,
      horizonMinutes: dto.horizon_minutes,
      cells: heatmap,
    };
  }

  async injectSyntheticEvent(dto: InjectSyntheticEventDto) {
    const scenarioType = dto.scenario_type.toUpperCase().trim();
    const neighbors = this.spatial.getInfluenceNeighbors(this.spatial.getH3Index(dto.lat, dto.lng), dto.radius_cells);
    const roadList = dto.affected_roads ?? [];
    const injections = [];

    const clusterCount = scenarioType === 'ACCIDENT_CLUSTER' ? Math.max(2, dto.cluster_size) : 1;
    for (let index = 0; index < clusterCount; index += 1) {
      const cell = neighbors[index % neighbors.length];
      const [lat, lng] = this.spatial.getCellCenter(cell);
      const mappedType = this.mapScenarioToDisruptionType(scenarioType);
      await this.db.query(
        `
          INSERT INTO simulation_events (scenario_id, event_type, severity, lat, lng, created_at)
          VALUES ($1, $2, $3, $4, $5, now())
        `,
        [dto.scenario_id, scenarioType, dto.severity, lat, lng],
      );

      injections.push(await this.disruptionPropagation.createDisruption({
        type: mappedType,
        lat,
        lng,
        start_time: new Date().toISOString(),
        severity: dto.severity,
        estimated_duration_minutes: dto.estimated_duration_minutes,
        affected_roads: roadList,
        kernel: mappedType === 'ROAD_CLOSURE' ? 'GAUSSIAN' : 'EXPONENTIAL',
      }));
    }

    for (const cell of neighbors) {
      const [lat, lng] = this.spatial.getCellCenter(cell);
      const current = await this.digitalTwin.getCurrentStateForCoordinate(lat, lng);
      const densityBoost = scenarioType === 'STADIUM_EVENT' || scenarioType === 'MASS_GATHERING'
        ? 0.35
        : scenarioType === 'ROAD_CLOSURE'
          ? 0.25
          : 0.18;
      const vehicleBoost = Math.max(20, Math.round(dto.attendee_count / Math.max(1, neighbors.length)));
      await this.digitalTwin.upsertCellState({
        city_id: 'default',
        lat,
        lng,
        traffic_density: Math.min(1.5, (current?.trafficDensity ?? 0.3) + densityBoost),
        average_speed: Math.max(5, (current?.averageSpeed ?? 32) - dto.severity * 3),
        disruption_weight: Math.min(1.5, (current?.disruptionWeight ?? 0.1) + dto.severity / 10),
        vehicle_count: (current?.vehicleCount ?? 40) + vehicleBoost,
      });
    }

    return {
      scenarioId: dto.scenario_id,
      scenarioType,
      injectedCells: neighbors.length,
      disruptions: injections.length,
    };
  }

  async simulateHorizons(dto: SimulateFutureHorizonDto) {
    const baseCells = await this.loadScenarioCells(dto);
    const outputs = [];
    for (const horizon of dto.horizons) {
      const steps = Math.max(1, Math.round(horizon / 5));
      const projected = baseCells.map((cell) => this.projectCell(cell, steps));
      outputs.push({
        horizonMinutes: horizon,
        congestion_map: projected.map((cell) => ({
          cellId: cell.cellId,
          congestionIndex: cell.trafficDensity,
        })),
        risk_map: projected.map((cell) => ({
          cellId: cell.cellId,
          riskScore: cell.riskScore,
        })),
        travel_delay_map: projected.map((cell) => ({
          cellId: cell.cellId,
          delayMinutes: cell.delayMinutes,
        })),
      });
    }

    return {
      cityId: dto.city_id,
      scenarioId: dto.scenario_id ?? null,
      outputs,
    };
  }

  async estimateEvacuation(dto: EstimateEvacuationDto) {
    const cells = await this.loadScenarioCells({
      city_id: 'default',
      minLat: dto.minLat,
      maxLat: dto.maxLat,
      minLng: dto.minLng,
      maxLng: dto.maxLng,
      horizon_minutes: 0,
    });
    const exitCells = dto.exit_routes.map((route) => this.spatial.getH3Index(route.lat, route.lng));
    const exitStates = await this.loadExitCapacities(exitCells);

    const totalVehicles = cells.reduce((sum, cell) => sum + cell.vehicleCount * dto.vehicle_density_factor, 0);
    const totalExitCapacity = exitStates.reduce(
      (sum, exit) => sum + Math.max(10, exit.roadCapacity * (1 - Math.min(0.8, exit.trafficDensity * 0.4))),
      0,
    );
    const weightedRisk = cells.reduce((sum, cell) => sum + cell.currentRisk, 0) / Math.max(1, cells.length);
    const clearanceMinutes = (totalVehicles / Math.max(totalExitCapacity, 1)) * 5 * (1 + weightedRisk);

    return {
      affectedCells: cells.length,
      totalVehicles: Math.round(totalVehicles),
      totalExitCapacity: Number(totalExitCapacity.toFixed(2)),
      estimatedClearanceMinutes: Number(clearanceMinutes.toFixed(2)),
      exitRoutes: exitStates.map((exit) => ({
        cellId: exit.cellId,
        roadCapacity: exit.roadCapacity,
        trafficDensity: exit.trafficDensity,
      })),
    };
  }

  async runOperatorSimulation(dto: SimulateEventDto) {
    const run = await this.db.query<QueryResultRow>(
      `
        INSERT INTO simulation_runs (
          scenario_id,
          scenario_type,
          status,
          requested_horizons,
          bounds
        )
        VALUES ($1, $2, 'QUEUED', $3::jsonb, $4::jsonb)
        RETURNING run_id::text AS run_id
      `,
      [
        dto.scenario_id,
        dto.scenario_type,
        JSON.stringify(dto.horizons),
        JSON.stringify(dto.bounds),
      ],
    );
    const runId = String(run.rows[0].run_id);

    try {
      const injection = await this.injectSyntheticEvent(dto);
      const riskSurface = await this.generateRiskSurface({
        city_id: 'default',
        minLat: dto.bounds.minLat,
        maxLat: dto.bounds.maxLat,
        minLng: dto.bounds.minLng,
        maxLng: dto.bounds.maxLng,
        horizon_minutes: 0,
      });
      const horizons = await this.simulateHorizons({
        city_id: 'default',
        scenario_id: dto.scenario_id,
        minLat: dto.bounds.minLat,
        maxLat: dto.bounds.maxLat,
        minLng: dto.bounds.minLng,
        maxLng: dto.bounds.maxLng,
        horizons: dto.horizons,
        horizon_minutes: 0,
      });

      await this.persistRunOutput(runId, 'RISK_SURFACE', {
        injection,
        riskSurface,
      });
      await this.persistRunOutput(runId, 'HORIZON_OUTPUTS', horizons);

      await this.db.query(
        `
          UPDATE simulation_runs
          SET status = 'COMPLETED',
              updated_at = now()
          WHERE run_id = $1::uuid
        `,
        [runId],
      );

      return {
        run_id: runId,
        scenario_id: dto.scenario_id,
        status: 'COMPLETED',
      };
    } catch (error) {
      await this.db.query(
        `
          UPDATE simulation_runs
          SET status = 'FAILED',
              updated_at = now()
          WHERE run_id = $1::uuid
        `,
        [runId],
      ).catch(() => undefined);
      throw error;
    }
  }

  async getSimulationResults(query: QuerySimulationResultsDto) {
    const run = await this.resolveRun(query);
    const outputs = await this.loadRunOutputs(run.run_id);
    return {
      run_id: run.run_id,
      scenario_id: run.scenario_id,
      scenario_type: run.scenario_type,
      status: run.status,
      created_at: run.created_at,
      outputs,
    };
  }

  async getRiskPredictions(query: QuerySimulationResultsDto) {
    const run = await this.resolveRun(query);
    const outputs = await this.loadRunOutputs(run.run_id);
    const riskSurface = outputs.find((entry) => entry.outputType === 'RISK_SURFACE')?.payload?.riskSurface ?? null;
    const horizonOutputs = outputs.find((entry) => entry.outputType === 'HORIZON_OUTPUTS')?.payload?.outputs ?? [];

    return {
      run_id: run.run_id,
      scenario_id: run.scenario_id,
      risk_surface: riskSurface,
      risk_predictions: horizonOutputs.map((entry: any) => ({
        horizonMinutes: entry.horizonMinutes,
        risk_map: entry.risk_map,
      })),
    };
  }

  private async loadScenarioCells(dto: GenerateRiskSurfaceDto) {
    const covering = this.spatial.getCoveringCells(dto.minLat, dto.minLng, dto.maxLat, dto.maxLng);
    if (covering.length === 0) {
      return [];
    }

    const result = await this.db.queryRead<ScenarioCellRow>(
      `
        WITH historical AS (
          SELECT
            (h3_index::h3index)::text AS cell_id,
            LEAST(1.0, COUNT(*)::double precision / 12.0) AS incident_probability
          FROM regional_geo_events_v
          WHERE observed_at >= now() - interval '30 days'
            AND h3_index = ANY($2::bigint[])
          GROUP BY h3_index
        ),
        disruptions AS (
          SELECT
            (dic.cell_id::h3index)::text AS cell_id,
            SUM(dic.influence_weight) AS disruption_proximity
          FROM disruption_influence_cells dic
          JOIN simulation_disruptions sd ON sd.id = dic.disruption_id
          WHERE sd.start_time <= now() + make_interval(mins => $3::int)
            AND sd.start_time + make_interval(mins => sd.estimated_duration_minutes) >= now()
            AND dic.cell_id = ANY($2::bigint[])
          GROUP BY dic.cell_id
        )
        SELECT
          (cg.cell_id::h3index)::text AS cell_id,
          cg.region_id::text AS region_id,
          cg.center_lat,
          cg.center_lng,
          cg.road_capacity,
          ds.traffic_density,
          ds.average_speed,
          ds.disruption_weight,
          ds.risk_score,
          ds.vehicle_count,
          COALESCE(historical.incident_probability, 0) AS historical_incident_probability,
          COALESCE(disruptions.disruption_proximity, 0) AS disruption_proximity
        FROM city_grid_cells cg
        LEFT JOIN digital_twin_cell_states ds ON ds.cell_id = cg.cell_id
        LEFT JOIN historical ON historical.cell_id = (cg.cell_id::h3index)::text
        LEFT JOIN disruptions ON disruptions.cell_id = (cg.cell_id::h3index)::text
        WHERE cg.city_id = $1
          AND cg.cell_id = ANY($2::bigint[])
      `,
      [dto.city_id, covering.map((cell) => this.spatial.toDbIndex(cell)), Math.trunc(dto.horizon_minutes)],
    );

    return result.rows.map((row) => ({
      cellId: row.cell_id,
      center: { lat: Number(row.center_lat), lng: Number(row.center_lng) },
      roadCapacity: Number(row.road_capacity ?? 250),
      trafficDensity: Number(row.traffic_density ?? 0),
      averageSpeed: Number(row.average_speed ?? 0),
      disruptionWeight: Number(row.disruption_weight ?? 0),
      currentRisk: Number(row.risk_score ?? 0),
      vehicleCount: Number(row.vehicle_count ?? 0),
      historicalIncidentProbability: Number((row.historical_incident_probability ?? 0)),
      disruptionProximity: Number((row.disruption_proximity ?? 0)),
    }));
  }

  private async loadExitCapacities(cells: string[]) {
    if (cells.length === 0) {
      return [];
    }
    const result = await this.db.queryRead<QueryResultRow>(
      `
        SELECT
          (cg.cell_id::h3index)::text AS cell_id,
          cg.road_capacity,
          COALESCE(ds.traffic_density, 0) AS traffic_density
        FROM city_grid_cells cg
        LEFT JOIN digital_twin_cell_states ds ON ds.cell_id = cg.cell_id
        WHERE cg.cell_id = ANY($1::bigint[])
      `,
      [cells.map((cell) => this.spatial.toDbIndex(cell))],
    );
    return result.rows.map((row) => ({
      cellId: String(row.cell_id),
      roadCapacity: Number(row.road_capacity ?? 250),
      trafficDensity: Number(row.traffic_density ?? 0),
    }));
  }

  private async resolveRun(query: QuerySimulationResultsDto) {
    const result = await this.db.queryRead<QueryResultRow>(
      `
        SELECT
          run_id::text AS run_id,
          scenario_id,
          scenario_type,
          status,
          created_at
        FROM simulation_runs
        WHERE ($1::uuid IS NOT NULL AND run_id = $1::uuid)
           OR ($1::uuid IS NULL AND $2::text IS NOT NULL AND scenario_id = $2::text)
        ORDER BY created_at DESC
        LIMIT 1
      `,
      [query.run_id ?? null, query.scenario_id ?? null],
    );

    if (result.rows.length === 0) {
      throw new Error('simulation run not found');
    }

    return {
      run_id: String(result.rows[0].run_id),
      scenario_id: String(result.rows[0].scenario_id),
      scenario_type: String(result.rows[0].scenario_type),
      status: String(result.rows[0].status),
      created_at: result.rows[0].created_at,
    };
  }

  private async loadRunOutputs(runId: string) {
    const result = await this.db.queryRead<QueryResultRow>(
      `
        SELECT output_type, payload, created_at
        FROM simulation_run_outputs
        WHERE run_id = $1::uuid
        ORDER BY created_at ASC
      `,
      [runId],
    );

    return result.rows.map((row) => ({
      outputType: String(row.output_type),
      payload: row.payload,
      createdAt: row.created_at,
    }));
  }

  private async persistRunOutput(runId: string, outputType: 'RISK_SURFACE' | 'HORIZON_OUTPUTS', payload: unknown) {
    await this.db.query(
      `
        INSERT INTO simulation_run_outputs (run_id, output_type, payload)
        VALUES ($1::uuid, $2, $3::jsonb)
        ON CONFLICT (run_id, output_type)
        DO UPDATE SET payload = EXCLUDED.payload, created_at = now()
      `,
      [runId, outputType, JSON.stringify(payload)],
    );
  }

  private combineRisk(
    trafficDensity: number,
    disruptionProximity: number,
    historicalIncidentProbability: number,
    currentRisk: number,
  ) {
    return Number(
      (
        1 -
        Math.exp(
          -(
            trafficDensity * 0.40 +
            disruptionProximity * 0.35 +
            historicalIncidentProbability * 0.30 +
            currentRisk * 0.25
          ),
        )
      ).toFixed(6),
    );
  }

  private mapScenarioToDisruptionType(scenarioType: string) {
    switch (scenarioType) {
      case 'ROAD_CLOSURE':
        return 'ROAD_CLOSURE';
      case 'STADIUM_EVENT':
      case 'MASS_GATHERING':
        return 'EVENT_CONGESTION';
      case 'ACCIDENT_CLUSTER':
        return 'ACCIDENT';
      default:
        return 'CONSTRUCTION';
    }
  }

  private projectCell(
    cell: {
      cellId: string;
      roadCapacity: number;
      trafficDensity: number;
      averageSpeed: number;
      disruptionProximity: number;
      historicalIncidentProbability: number;
      currentRisk: number;
      vehicleCount: number;
    },
    steps: number,
  ) {
    let density = cell.trafficDensity;
    let speed = cell.averageSpeed || 30;
    let vehicles = cell.vehicleCount || 40;
    let risk = cell.currentRisk;

    for (let step = 0; step < steps; step += 1) {
      density = Math.min(
        1.5,
        Math.max(
          0,
          density * 0.96 +
          cell.disruptionProximity * 0.06 +
          cell.historicalIncidentProbability * 0.04,
        ),
      );
      speed = Math.max(
        0,
        speed * (1 - Math.min(0.80, density * 0.20 + cell.disruptionProximity * 0.16 + cell.historicalIncidentProbability * 0.08)),
      );
      vehicles = Math.max(0, vehicles * (0.99 + Math.min(0.03, density * 0.02)));
      risk = this.combineRisk(density, cell.disruptionProximity, cell.historicalIncidentProbability, risk);
    }

    const delayMinutes = Number(
      Math.max(0, ((Math.max(cell.averageSpeed || 30, 1) - speed) / Math.max(cell.averageSpeed || 30, 1)) * 12).toFixed(2),
    );

    return {
      cellId: cell.cellId,
      trafficDensity: Number(density.toFixed(4)),
      riskScore: risk,
      delayMinutes,
      averageSpeed: Number(speed.toFixed(2)),
      vehicleCount: Math.round(vehicles),
    };
  }
}
