#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required"
  exit 1
fi

plan="$(psql "$DATABASE_URL" -tA -c "EXPLAIN (ANALYZE, VERBOSE, BUFFERS) SELECT * FROM calculate_route_risk_v3(ST_GeogFromText('LINESTRING(77.2090 28.6139, 77.2100 28.6145)'));")"
echo "$plan"

if grep -q "Seq Scan on geo_events" <<< "$plan"; then
  echo "Plan validation failed: /risk path scanned geo_events"
  exit 1
fi

fn_def="$(psql "$DATABASE_URL" -tA -c "SELECT pg_get_functiondef('calculate_route_risk_v3(geography,double precision,double precision)'::regprocedure);")"
if ! grep -q "JOIN risk_cells" <<< "$fn_def"; then
  echo "Plan validation failed: calculate_route_risk_v3 does not join risk_cells"
  exit 1
fi

if grep -q "FROM geo_events" <<< "$fn_def"; then
  echo "Plan validation failed: calculate_route_risk_v3 references geo_events"
  exit 1
fi

echo "Risk query plan validation passed"
