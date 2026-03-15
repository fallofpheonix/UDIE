import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { RiskGridService } from '../risk/risk-grid.service';
import { SpatialService } from '../common/spatial.service';

@Injectable()
export class AggregationWorker implements OnModuleInit {
    private readonly logger = new Logger(AggregationWorker.name);
    private readonly reconnectDelayMs = 5_000;
    private sequenceEnsured = false;

    constructor(
        private readonly db: DatabaseService,
        private readonly riskGrid: RiskGridService,
        private readonly spatial: SpatialService,
    ) { }

    async onModuleInit() {
        await this.ensureRiskVersionSequence();
        void this.setupListener();
    }

    /**
     * Sets up the PostgreSQL LISTEN/NOTIFY listener.
     * Law: Updates are triggered by immutable logs in real-time.
     */
    private async setupListener() {
        let client: any;

        try {
            client = await this.db.getPool().connect();
            await client.query('LISTEN risk_update');
            this.logger.log('[AGGREGATOR] Listening for risk_update notifications...');

            client.on('notification', async (msg: any) => {
                if (msg.channel === 'risk_update' && msg.payload) {
                    const payload = JSON.parse(msg.payload);
                    await this.processLogEntry(payload.id, payload.h3_parent);
                }
            });

            client.on('error', (error: any) => {
                this.logger.error(`[AGGREGATOR] Listener connection error: ${error.message}`);
                try { client.release(); } catch { }
                setTimeout(() => void this.setupListener(), this.reconnectDelayMs);
            });
        } catch (error: any) {
            this.logger.error(`[AGGREGATOR] Listener failed: ${error.message}`);
            try { client?.release(); } catch { }
            setTimeout(() => void this.setupListener(), this.reconnectDelayMs);
        }
    }

    /**
     * Processes a single log entry and updates the risk surface (O(neighbor_cells)).
     */
    private async processLogEntry(logId: string, h3Parent: string) {
        try {
            // 1. Fetch the simplified event data
            const result = await this.db.query(`
        SELECT 
          CASE
            WHEN payload ? 'h3_cell' THEN payload->>'h3_cell'
            WHEN payload->>'h3_index' ~ '^[0-9]+$' THEN (((payload->>'h3_index')::bigint)::h3index)::text
            ELSE ((payload->>'h3_index')::h3index)::text
          END AS h3_cell,
          (payload->>'severity_hint')::double precision as severity,
          COALESCE((payload->>'confidence_hint')::double precision, (payload->>'reliability_score')::double precision, 1.0) AS confidence
        FROM regional_events_log
        WHERE id = $1 AND h3_parent = $2::bigint
      `, [logId, h3Parent]);

            if (result.rows.length === 0) return;

            const { h3_cell, severity, confidence } = result.rows[0];
            const h3CellStr = h3_cell.toString();

            // 2. Incremental Update: Center Cell
            // Using log-reinforcement: weight += severity * log(1 + count)
            // For streaming, we approximate delta. Defaulting to linear for v1.
            const delta = Number(severity) * Number(confidence);

            await this.applyRiskDelta(h3CellStr, h3Parent, delta);

            // 3. Propagate Influence to Neighbors (O(neighbor_cells))
            const rings = 1; // Res 9 ring 1 is ~300m
            const neighbors = this.spatial.getInfluenceNeighbors(h3CellStr, rings);

            for (const neighbor of neighbors) {
                // Simple distance decay: 50% for ring 1
                await this.applyRiskDelta(neighbor, h3Parent, delta * 0.5);
            }

            this.logger.debug(`[AGGREGATOR] log=${logId} cell=${h3CellStr} neighbors=${neighbors.length} status=PROCESSED`);
        } catch (error: any) {
            this.logger.error(`[AGGREGATOR] Failed to process log ${logId}: ${error.message}`);
        }
    }

    /**
     * Applies a weight delta to both In-Memory and Persistent state.
     */
    private async applyRiskDelta(h3Index: string, h3Parent: string, delta: number) {
        await this.ensureRiskVersionSequence();
        // A. Update In-Memory Grid (Evaluate Hot-Path)
        this.riskGrid.updateWeight(h3Index, delta);

        // B. Update Persistent Partitioned Grid (Audit Trail / Rebuildable State)
        await this.db.query(`
      INSERT INTO regional_risk_grid_v (h3_index, h3_parent, version, weight)
      VALUES (($1::h3index)::bigint, $2::bigint, nextval('risk_version_seq'), $3)
      ON CONFLICT (h3_index, version, h3_parent) DO NOTHING
    `, [h3Index, h3Parent, delta]);
    }

    private async ensureRiskVersionSequence() {
        if (this.sequenceEnsured) {
            return;
        }
        await this.db.query(`CREATE SEQUENCE IF NOT EXISTS risk_version_seq`);
        this.sequenceEnsured = true;
    }
}
