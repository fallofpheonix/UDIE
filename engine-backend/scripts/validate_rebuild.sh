#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required"
  exit 1
fi

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "SELECT rebuild_derived_state_from_log();"
before="$(psql "$DATABASE_URL" -tA -c "SELECT md5(COALESCE(string_agg(h3_index::text || ':' || round(weight::numeric,6)::text, ',' ORDER BY h3_index), '')) FROM risk_cells;")"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "SELECT rebuild_derived_state_from_log();"
after="$(psql "$DATABASE_URL" -tA -c "SELECT md5(COALESCE(string_agg(h3_index::text || ':' || round(weight::numeric,6)::text, ',' ORDER BY h3_index), '')) FROM risk_cells;")"

echo "rebuild_hash_before=$before"
echo "rebuild_hash_after=$after"

if [[ "$before" != "$after" ]]; then
  echo "Rebuild validation failed: risk_cells mismatch"
  exit 1
fi

echo "Rebuild validation passed"
