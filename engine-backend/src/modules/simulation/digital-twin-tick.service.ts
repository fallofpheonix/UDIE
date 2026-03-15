import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { DigitalTwinStateStoreService } from './digital-twin-state-store.service';
import { TwinCellState } from './digital-twin.types';

type TickRow = QueryResultRow & {
  cell_id: string;
  region_id: string;
  traffic_density: number;
  average_speed: number;
  disruption_weight: number;
  risk_score: number;
  vehicle_count: number;
  timestamp: Date | string | null;
};

@Injectable()
export class DigitalTwinTickService {
  private readonly logger = new Logger(DigitalTwinTickService.name);
  private readonly workerLockTimeoutSeconds = 12;
  private readonly maxRiskScore = 0.999999;

  constructor(
    private readonly db: DatabaseService,
    private readonly store: DigitalTwinStateStoreService,
  ) {}

  @Cron('*/5 * * * * *')
  async advanceTick() {
    const workerName = 'digital_twin_tick_worker';
    const lockId = 777124;

    try {
      const advisory = await this.db.query<{ pg_try_advisory_lock: boolean }>(
        'SELECT pg_try_advisory_lock($1)',
        [lockId],
      );
      if (!advisory.rows[0]?.pg_try_advisory_lock) {
        return;
      }

      try {
        const lock = await this.db.query<{ acquire_worker_lock: boolean }>(
          'SELECT acquire_worker_lock($1, $2)',
          [workerName, this.workerLockTimeoutSeconds],
        );
        if (!lock.rows[0]?.acquire_worker_lock) {
          return;
        }

        const updated = await this.db.query<TickRow>(
          `
            WITH base AS (
              SELECT
                ds.cell_id,
                ds.region_id,
                cg.road_capacity,
                ds.traffic_density,
                ds.average_speed,
                ds.disruption_weight,
                ds.vehicle_count,
                COALESCE(rc.weight, 0) AS surface_risk,
                COALESCE(di.disruption_weight, 0) AS propagated_disruption
              FROM digital_twin_cell_states ds
              JOIN city_grid_cells cg ON cg.cell_id = ds.cell_id
              LEFT JOIN risk_cells rc ON rc.h3_index = ds.cell_id
              LEFT JOIN (
                SELECT
                  dic.cell_id,
                  SUM(dic.influence_weight) AS disruption_weight
                FROM disruption_influence_cells dic
                JOIN simulation_disruptions sd ON sd.id = dic.disruption_id
                WHERE sd.start_time <= now()
                  AND sd.start_time + make_interval(mins => sd.estimated_duration_minutes) >= now()
                GROUP BY dic.cell_id
              ) di ON di.cell_id = ds.cell_id
              WHERE ds.timestamp >= now() - interval '6 hours'
            ),
            transfer_raw AS (
              SELECT
                edge.source_cell_id,
                edge.target_cell_id,
                LEAST(
                  edge.transfer_capacity,
                  base.vehicle_count * LEAST(
                    0.20,
                    GREATEST(
                      0.02,
                      (base.average_speed / 120.0) * (1 - LEAST(0.70, base.propagated_disruption))
                    )
                  )
                ) *
                edge.directional_bias *
                (1 - LEAST(0.90, (COALESCE(target.traffic_density, 0) + COALESCE(target.propagated_disruption, 0)) / 2.0)) AS transfer_units
              FROM city_grid_edges edge
              JOIN base ON base.cell_id = edge.source_cell_id
              LEFT JOIN base target ON target.cell_id = edge.target_cell_id
            ),
            transfer_balances AS (
              SELECT
                cell_id,
                SUM(inflow) AS inflow,
                SUM(outflow) AS outflow
              FROM (
                SELECT target_cell_id AS cell_id, transfer_units AS inflow, 0::double precision AS outflow
                FROM transfer_raw
                UNION ALL
                SELECT source_cell_id AS cell_id, 0::double precision AS inflow, transfer_units AS outflow
                FROM transfer_raw
              ) movements
              GROUP BY cell_id
            ),
            evolved AS (
              SELECT
                base.cell_id,
                base.region_id,
                LEAST(
                  1.5,
                  GREATEST(
                    0,
                    (
                      base.vehicle_count
                      - COALESCE(balance.outflow, 0)
                      + COALESCE(balance.inflow, 0)
                    ) / GREATEST(base.road_capacity, 1)
                  ) + (base.disruption_weight + base.propagated_disruption) * 0.05 + base.surface_risk * 0.12
                ) AS next_density,
                GREATEST(
                  0,
                  base.average_speed * (
                    1 - LEAST(
                      0.85,
                      (
                        (
                          base.vehicle_count
                          - COALESCE(balance.outflow, 0)
                          + COALESCE(balance.inflow, 0)
                        ) / GREATEST(base.road_capacity, 1)
                      ) * 0.22 + (base.disruption_weight + base.propagated_disruption) * 0.12 + base.surface_risk * 0.20
                    )
                  )
                ) AS next_speed,
                LEAST(1.5, GREATEST(0, (base.disruption_weight + base.propagated_disruption) * 0.94 + base.surface_risk * 0.08)) AS next_disruption,
                GREATEST(
                  0,
                  ROUND(
                    base.vehicle_count
                    - COALESCE(balance.outflow, 0)
                    + COALESCE(balance.inflow, 0)
                  )
                )::INT AS next_vehicle_count,
                LEAST(
                  $1,
                  GREATEST(
                    0,
                    1 - exp(-(
                      (
                        (
                          base.vehicle_count
                          - COALESCE(balance.outflow, 0)
                          + COALESCE(balance.inflow, 0)
                        ) / GREATEST(base.road_capacity, 1)
                      ) * 0.35
                      + (base.disruption_weight + base.propagated_disruption) * 0.40
                      + base.surface_risk * 0.85
                    ))
                  )
                ) AS next_risk
              FROM base
              LEFT JOIN transfer_balances balance ON balance.cell_id = base.cell_id
            )
            UPDATE digital_twin_cell_states ds
            SET
              traffic_density = evolved.next_density,
              average_speed = evolved.next_speed,
              disruption_weight = evolved.next_disruption,
              risk_score = evolved.next_risk,
              vehicle_count = evolved.next_vehicle_count,
              timestamp = now(),
              updated_at = now()
            FROM evolved
            WHERE ds.cell_id = evolved.cell_id
            RETURNING
              (ds.cell_id::h3index)::text AS cell_id,
              ds.region_id::text AS region_id,
              ds.traffic_density,
              ds.average_speed,
              ds.disruption_weight,
              ds.risk_score,
              ds.vehicle_count,
              ds.timestamp
          `,
          [this.maxRiskScore],
        );

        await this.store.upsertMany(updated.rows.map((row) => this.mapRow(row)));

        await this.db.query(
          `
            INSERT INTO digital_twin_horizon_states (
              horizon_at,
              cell_id,
              region_id,
              traffic_density,
              average_speed,
              disruption_weight,
              risk_score,
              vehicle_count
            )
            SELECT
              now() + interval '5 minutes',
              ds.cell_id,
              ds.region_id,
              LEAST(1.5, ds.traffic_density * 0.98 + ds.disruption_weight * 0.03 + ds.risk_score * 0.04),
              GREATEST(0, ds.average_speed * (1 - LEAST(0.75, ds.traffic_density * 0.12 + ds.risk_score * 0.10))),
              LEAST(1.5, ds.disruption_weight * 0.96 + ds.risk_score * 0.05),
              LEAST($1, GREATEST(0, ds.risk_score * 0.97 + ds.disruption_weight * 0.04)),
              GREATEST(0, ROUND(ds.vehicle_count * (0.99 + LEAST(0.02, ds.risk_score * 0.01))))::INT
            FROM digital_twin_cell_states ds
            WHERE ds.timestamp >= now() - interval '6 hours'
            ON CONFLICT (horizon_at, cell_id) DO NOTHING
          `,
          [this.maxRiskScore],
        );

        await this.db.query(
          `SELECT set_system_state($1, $2::jsonb)`,
          [
            workerName,
            JSON.stringify({
              status: 'OK',
              ticked_cells: updated.rows.length,
              last_success_at: new Date().toISOString(),
            }),
          ],
        );
      } finally {
        await this.db.query('SELECT pg_advisory_unlock($1)', [lockId]);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown';
      await this.db.query(
        `SELECT set_system_state($1, $2::jsonb)`,
        [
          workerName,
          JSON.stringify({
            status: 'FAILED',
            error: message,
            last_failure_at: new Date().toISOString(),
          }),
        ],
      ).catch(() => undefined);
      this.logger.warn(`[TWIN_TICK] failed=${message}`);
    }
  }

  @Cron('0 * * * * *')
  async snapshotStates() {
    const workerName = 'digital_twin_snapshot_worker';
    const lockId = 777125;

    try {
      const advisory = await this.db.query<{ pg_try_advisory_lock: boolean }>(
        'SELECT pg_try_advisory_lock($1)',
        [lockId],
      );
      if (!advisory.rows[0]?.pg_try_advisory_lock) {
        return;
      }

      try {
        const lock = await this.db.query<{ acquire_worker_lock: boolean }>(
          'SELECT acquire_worker_lock($1, $2)',
          [workerName, 120],
        );
        if (!lock.rows[0]?.acquire_worker_lock) {
          return;
        }

        const result = await this.db.query<{ count: number }>(
          `
            WITH inserted AS (
              INSERT INTO digital_twin_state_snapshots (
                snapshot_at,
                cell_id,
                region_id,
                traffic_density,
                average_speed,
                disruption_weight,
                risk_score,
                vehicle_count
              )
              SELECT
                now(),
                cell_id,
                region_id,
                traffic_density,
                average_speed,
                disruption_weight,
                risk_score,
                vehicle_count
              FROM digital_twin_cell_states
              WHERE timestamp >= now() - interval '6 hours'
              RETURNING 1
            )
            SELECT COUNT(*)::int AS count FROM inserted
          `,
        );

        await this.db.query(
          `SELECT set_system_state($1, $2::jsonb)`,
          [
            workerName,
            JSON.stringify({
              status: 'OK',
              snapshot_cells: result.rows[0]?.count ?? 0,
              last_success_at: new Date().toISOString(),
            }),
          ],
        );
      } finally {
        await this.db.query('SELECT pg_advisory_unlock($1)', [lockId]);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown';
      await this.db.query(
        `SELECT set_system_state($1, $2::jsonb)`,
        [
          workerName,
          JSON.stringify({
            status: 'FAILED',
            error: message,
            last_failure_at: new Date().toISOString(),
          }),
        ],
      ).catch(() => undefined);
      this.logger.warn(`[TWIN_SNAPSHOT] failed=${message}`);
    }
  }

  private mapRow(row: TickRow): TwinCellState {
    return {
      cellId: row.cell_id,
      regionId: row.region_id,
      trafficDensity: Number(row.traffic_density ?? 0),
      averageSpeed: Number(row.average_speed ?? 0),
      disruptionWeight: Number(row.disruption_weight ?? 0),
      riskScore: Number(row.risk_score ?? 0),
      vehicleCount: Number(row.vehicle_count ?? 0),
      timestamp: row.timestamp ? new Date(row.timestamp).toISOString() : null,
    };
  }
}
