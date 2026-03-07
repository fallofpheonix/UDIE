import { Client } from 'pg';

const DATABASE_URL = process.env.DATABASE_URL ?? 'postgresql://udie:udie@localhost:5432/udie';

async function main() {
  const client = new Client({ connectionString: DATABASE_URL });
  await client.connect();

  try {
    console.log('[intel-eval] starting');

    const thresholdRows = await client.query(
      `SELECT key, value
       FROM model_parameters
       WHERE key = ANY($1)
       ORDER BY key`,
      [[
        'INTEL_HOTSPOT_THRESHOLD',
        'INTEL_HOT_NEIGHBORS_MIN',
        'INTEL_RECURRING_EVENTS_24H',
        'INTEL_SPIKE_MULTIPLIER',
        'INTEL_SPIKE_WINDOW_MINUTES',
        'INTEL_SCAN_LIMIT',
      ]],
    );

    console.log(`[intel-eval] thresholds_loaded=${thresholdRows.rows.length}`);

    const distribution = await client.query(
      `SELECT pattern_type, severity, COUNT(*)::int AS count
       FROM intelligence_events
       WHERE created_at >= now() - interval '24 hours'
       GROUP BY pattern_type, severity
       ORDER BY pattern_type, severity`,
    );

    console.log('[intel-eval] 24h_distribution=', JSON.stringify(distribution.rows));

    const latencyProbe = await client.query(
      `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
       SELECT h3_index, pattern_type, severity
       FROM intelligence_events
       ORDER BY created_at DESC
       LIMIT 50`,
    );

    const planText = latencyProbe.rows.map((r) => Object.values(r)[0]).join('\n');
    if (/Seq Scan/i.test(planText)) {
      console.error('[intel-eval][warn] sequential scan detected on intelligence_events query');
    }

    console.log('[intel-eval][pass] evaluation completed');
  } finally {
    await client.end();
  }
}

void main();
