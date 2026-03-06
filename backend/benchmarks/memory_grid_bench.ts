import { Client } from 'pg';
import * as h3 from 'h3-js';
import { createHash } from 'crypto';

const DATABASE_URL = process.env.DATABASE_URL ?? 'postgresql://udie:udie@localhost:5432/udie';
const SAMPLE_SIZE = Number(process.env.GRID_SAMPLE_SIZE ?? 100);
const ROUTE_RUNS = Number(process.env.GRID_ROUTE_RUNS ?? 1000);

const SAMPLE_ROUTE = [
  { lat: 28.6139, lng: 77.2090 },
  { lat: 28.6148, lng: 77.2108 },
  { lat: 28.6162, lng: 77.2121 },
  { lat: 28.6170, lng: 77.2130 },
];

function routeCells(coords: Array<{ lat: number; lng: number }>): string[] {
  const cells = new Set<string>();
  for (let i = 0; i < coords.length - 1; i++) {
    const a = h3.latLngToCell(coords[i].lat, coords[i].lng, 9);
    const b = h3.latLngToCell(coords[i + 1].lat, coords[i + 1].lng, 9);
    for (const c of h3.gridPathCells(a, b)) {
      cells.add(c);
    }
  }
  return Array.from(cells);
}

function evalRiskMemory(grid: Map<string, number>, cells: string[]): number {
  let total = 0;
  for (const c of cells) {
    total += grid.get(c) ?? 0;
  }
  return total;
}

async function riskCellsHash(client: Client): Promise<string> {
  const result = await client.query(
    `SELECT h3_index::text AS h3_index, weight::text AS weight
     FROM risk_cells
     ORDER BY h3_index`,
  );

  const payload = result.rows.map((r) => `${r.h3_index}:${r.weight}`).join('|');
  return createHash('sha256').update(payload).digest('hex');
}

async function main() {
  const client = new Client({ connectionString: DATABASE_URL });
  await client.connect();

  try {
    console.log('[memory-grid] starting benchmarks');

    // Hydrate memory map from risk_cells authoritative storage
    const gridRows = await client.query(
      `SELECT (h3_index::h3index)::text AS h3_index, weight
       FROM risk_cells`,
    );

    const grid = new Map<string, number>();
    for (const row of gridRows.rows) {
      grid.set(String(row.h3_index), Number(row.weight));
    }

    console.log(`[memory-grid] hydrated cells=${grid.size}`);

    // 1) Consistency check
    const sampleRows = await client.query(
      `SELECT (h3_index::h3index)::text AS h3_index, weight
       FROM risk_cells
       ORDER BY updated_at DESC
       LIMIT $1`,
      [SAMPLE_SIZE],
    );

    let mismatches = 0;
    for (const row of sampleRows.rows) {
      const key = String(row.h3_index);
      const persisted = Number(row.weight);
      const inMemory = grid.get(key) ?? 0;
      if (Math.abs(persisted - inMemory) > 1e-9) {
        mismatches += 1;
      }
    }

    console.log(`[memory-grid] consistency mismatches=${mismatches}/${sampleRows.rows.length}`);

    // 2) Rebuild determinism check
    const beforeHash = await riskCellsHash(client);
    await client.query('SELECT rebuild_derived_state_from_log()');
    const afterHash = await riskCellsHash(client);
    const deterministic = beforeHash === afterHash;

    console.log(`[memory-grid] determinism before=${beforeHash} after=${afterHash} equal=${deterministic}`);

    // 3) Latency benchmark (memory only)
    const cells = routeCells(SAMPLE_ROUTE);
    const timings: number[] = [];

    for (let i = 0; i < ROUTE_RUNS; i++) {
      const t0 = performance.now();
      evalRiskMemory(grid, cells);
      timings.push(performance.now() - t0);
    }

    timings.sort((a, b) => a - b);
    const p50 = timings[Math.floor(timings.length * 0.5)] ?? 0;
    const p95 = timings[Math.floor(timings.length * 0.95)] ?? 0;
    const avg = timings.reduce((a, b) => a + b, 0) / Math.max(timings.length, 1);

    console.log(`[memory-grid] latency avg_ms=${avg.toFixed(4)} p50_ms=${p50.toFixed(4)} p95_ms=${p95.toFixed(4)}`);

    // Process exit discipline for CI gates
    if (mismatches > 0) {
      console.error('[memory-grid][fail] consistency check failed');
      process.exitCode = 2;
      return;
    }
    if (!deterministic) {
      console.error('[memory-grid][fail] determinism check failed');
      process.exitCode = 3;
      return;
    }

    console.log('[memory-grid][pass] all checks passed');
  } finally {
    await client.end();
  }
}

void main();
