import { Client } from 'pg';

// UDIE Sprint 1: Scale Proof Benchmark
// Goal: Prove O(cells) join performance independent of total event count.

const DB_CONFIG = {
    connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/udie',
};

const SAMPLE_ROUTE = [
    { lat: 28.6139, lng: 77.2090 }, // New Delhi
    { lat: 28.6145, lng: 77.2100 },
    { lat: 28.6155, lng: 77.2115 },
    { lat: 28.6170, lng: 77.2130 },
];

async function runBenchmark(eventCount: number) {
    const client = new Client(DB_CONFIG);
    await client.connect();

    console.log(`\n--- BENCHMARK: ${eventCount} EVENTS ---`);

    try {
        // 1. Cleanup
        await client.query('TRUNCATE events_log, geo_events, risk_cells CASCADE');

        // 2. Generate Mock Data (Bulk Insert)
        const startGen = Date.now();
        console.log(`Generating ${eventCount} events around Delhi...`);

        // Using simple points around Delhi for high density
        for (let i = 0; i < eventCount; i += 5000) {
            const batchSize = Math.min(5000, eventCount - i);
            const query = `
            INSERT INTO geo_events (event_type, severity, confidence, geom, city_code, status, h3_index, observed_at)
            SELECT
                'CONSTRUCTION',
                GREATEST(1, LEAST(5, floor(random() * 5 + 1)::int)),
                0.7,
                ST_SetSRID(ST_MakePoint(p.lng, p.lat), 4326)::geography,
                'DEL',
                'ACTIVE',
                h3_lat_lng_to_cell(point(p.lat, p.lng), 9)::bigint,
                now()
            FROM (
              SELECT
                28.6139 + (random() - 0.5) * 0.1 AS lat,
                77.2090 + (random() - 0.5) * 0.1 AS lng
              FROM generate_series(1, ${batchSize})
            ) p;
        `;
            await client.query(query);
        }
        console.log(`Data generated in ${Date.now() - startGen}ms`);

        // 3. Run Materialization
        const startMat = Date.now();
        await client.query('SELECT refresh_risk_surface()');
        console.log(`Risk surface materialized in ${Date.now() - startMat}ms`);

        // 4. Measure Query Latency (Hot Path)
        const lineString = `LINESTRING(${SAMPLE_ROUTE.map(p => `${p.lng} ${p.lat}`).join(', ')})`;

        console.log('Running 50 trial queries...');
        const latencies: number[] = [];
        for (let i = 0; i < 50; i++) {
            const startQuery = performance.now();
            await client.query('SELECT * FROM calculate_route_risk_v3(ST_GeogFromText($1))', [lineString]);
            latencies.push(performance.now() - startQuery);
        }

        const avg = latencies.reduce((a, b) => a + b) / latencies.length;
        const p95 = latencies.sort((a, b) => a - b)[Math.floor(latencies.length * 0.95)];

        console.log(`AVERAGE LATENCY: ${avg.toFixed(2)}ms`);
        console.log(`P95 LATENCY: ${p95.toFixed(2)}ms`);

    } finally {
        await client.end();
    }
}

async function main() {
    // Comparing 1k vs 10k vs 100k events to prove O(cells)
    await runBenchmark(1000);
    await runBenchmark(10000);
    await runBenchmark(100000);
}

main().catch(console.error);
