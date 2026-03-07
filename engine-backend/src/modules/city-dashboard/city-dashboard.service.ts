import { Injectable } from '@nestjs/common';
import * as h3 from 'h3-js';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../database/database.service';
import { QueryCityDashboardDto } from './dto/query-city-dashboard.dto';

type CellRow = QueryResultRow & { h3_index: string; weight: number };

@Injectable()
export class CityDashboardService {
  constructor(private readonly db: DatabaseService) {}

  async getDashboard(query: QueryCityDashboardDto) {
    const bboxCells = this.getBoundingCells(query);
    if (bboxCells.length === 0) {
      return { heatmapSummary: { cells: 0, avgRisk: 0, maxRisk: 0 }, topHotspots: [], recentIncidents: [], cityRiskTrend: [] };
    }

    const threshold = Number(query.hotspotThreshold ?? 8);
    const [heatmapSummary, topHotspots, recentIncidents, cityRiskTrend] = await Promise.all([
      this.getHeatmapSummary(bboxCells),
      this.getTopHotspots(bboxCells, threshold),
      this.getRecentIncidents(bboxCells),
      this.getTrend(bboxCells),
    ]);

    return { heatmapSummary, topHotspots, recentIncidents, cityRiskTrend };
  }

  private async getHeatmapSummary(cells: string[]) {
    const result = await this.db.query<QueryResultRow>(
      `SELECT COUNT(*)::int AS cells, COALESCE(AVG(weight), 0) AS avg_risk, COALESCE(MAX(weight), 0) AS max_risk
       FROM risk_cells
       WHERE h3_index = ANY(ARRAY(SELECT (cell::h3index)::bigint FROM unnest($1::text[]) AS cell))`,
      [cells],
    );
    const row = result.rows[0];
    return {
      cells: Number(row?.cells ?? 0),
      avgRisk: Number(row?.avg_risk ?? 0),
      maxRisk: Number(row?.max_risk ?? 0),
    };
  }

  private async getTopHotspots(cells: string[], threshold: number) {
    const result = await this.db.query<CellRow>(
      `SELECT (h3_index::h3index)::text AS h3_index, weight
       FROM risk_cells
       WHERE h3_index = ANY(ARRAY(SELECT (cell::h3index)::bigint FROM unnest($1::text[]) AS cell))
         AND weight >= $2
       ORDER BY weight DESC
       LIMIT 600`,
      [cells, threshold],
    );

    const byCell = new Map<string, number>();
    for (const row of result.rows) {
      byCell.set(String(row.h3_index), Number(row.weight));
    }

    const visited = new Set<string>();
    const clusters: Array<{ cells: string[]; aggregatedRisk: number; peakRisk: number }> = [];

    for (const cell of byCell.keys()) {
      if (visited.has(cell)) continue;
      const queue = [cell];
      visited.add(cell);
      const clusterCells: string[] = [];
      let aggregatedRisk = 0;
      let peakRisk = 0;

      while (queue.length > 0) {
        const current = queue.shift() as string;
        clusterCells.push(current);
        const w = byCell.get(current) ?? 0;
        aggregatedRisk += w;
        if (w > peakRisk) peakRisk = w;

        const neighbors = h3.gridDisk(current, 1);
        for (const neighbor of neighbors) {
          if (!byCell.has(neighbor) || visited.has(neighbor)) continue;
          visited.add(neighbor);
          queue.push(neighbor);
        }
      }

      clusters.push({ cells: clusterCells, aggregatedRisk, peakRisk });
    }

    clusters.sort((a, b) => b.aggregatedRisk - a.aggregatedRisk);

    return clusters.slice(0, 10).map((cluster, idx) => ({
      rank: idx + 1,
      aggregatedRisk: Number(cluster.aggregatedRisk.toFixed(3)),
      peakRisk: Number(cluster.peakRisk.toFixed(3)),
      cellCount: cluster.cells.length,
      cells: cluster.cells,
    }));
  }

  private async getRecentIncidents(cells: string[]) {
    const result = await this.db.query<QueryResultRow>(
      `SELECT event_type, severity, confidence,
              ST_Y(geom::geometry) AS lat,
              ST_X(geom::geometry) AS lng,
              observed_at
       FROM regional_geo_events_v
       WHERE observed_at >= now() - interval '6 hours'
         AND h3_index = ANY(ARRAY(SELECT (cell::h3index)::bigint FROM unnest($1::text[]) AS cell))
       ORDER BY observed_at DESC
       LIMIT 30`,
      [cells],
    );

    return result.rows.map((row) => ({
      eventType: String(row.event_type),
      severity: Number(row.severity),
      confidence: Number(row.confidence),
      lat: Number(row.lat),
      lng: Number(row.lng),
      observedAt: row.observed_at,
    }));
  }

  private async getTrend(cells: string[]) {
    const result = await this.db.query<QueryResultRow>(
      `SELECT snapshot_time, AVG(risk_weight) AS avg_risk, MAX(risk_weight) AS max_risk
       FROM risk_snapshots
       WHERE snapshot_time >= now() - interval '24 hours'
         AND h3_index = ANY(ARRAY(SELECT (cell::h3index)::bigint FROM unnest($1::text[]) AS cell))
       GROUP BY snapshot_time
       ORDER BY snapshot_time ASC
       LIMIT 288`,
      [cells],
    );

    return result.rows.map((row) => ({
      snapshotTime: row.snapshot_time,
      avgRisk: Number(row.avg_risk),
      maxRisk: Number(row.max_risk),
    }));
  }

  private getBoundingCells(query: QueryCityDashboardDto): string[] {
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
