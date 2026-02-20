#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
BENCH_SCRIPT="$BACKEND_DIR/scripts/benchmark_replay.sh"
MIGRATE_SCRIPT="$BACKEND_DIR/scripts/migrate_all.sh"

echo "[verify] root=$ROOT_DIR"

if [[ ! -d "$BACKEND_DIR/benchmarks" ]]; then
  echo "[verify][fail] missing directory: $BACKEND_DIR/benchmarks"
  exit 1
fi
echo "[verify][ok] benchmark directory exists"

if [[ ! -f "$BENCH_SCRIPT" ]]; then
  echo "[verify][fail] missing benchmark replay script: $BENCH_SCRIPT"
  exit 1
fi

if [[ "${VERIFY_RUN_MIGRATIONS:-0}" == "1" ]]; then
  if [[ ! -f "$MIGRATE_SCRIPT" ]]; then
    echo "[verify][fail] missing migrate script: $MIGRATE_SCRIPT"
    exit 1
  fi
  echo "[verify] applying migrations"
  DATABASE_URL="${DATABASE_URL:-postgresql://udie:udie@localhost:5432/udie}" \
    bash "$MIGRATE_SCRIPT"
  echo "[verify][ok] migrations applied"
else
  echo "[verify] skipping migrations (set VERIFY_RUN_MIGRATIONS=1 to enable)"
fi

echo "[verify] running benchmark replay"
DATABASE_URL="${DATABASE_URL:-postgresql://udie:udie@localhost:5432/udie}" \
  bash "$BENCH_SCRIPT"
echo "[verify][ok] benchmark replay completed"

echo "[verify] checking forbidden ORM packages/imports"
if rg -n "@prisma|PrismaClient|typeorm|TypeORM|sequelize|mongoose|drizzle" \
  "$BACKEND_DIR/src" "$BACKEND_DIR/package.json" > /tmp/verify_orm_hits.txt; then
  echo "[verify][fail] forbidden ORM usage detected:"
  cat /tmp/verify_orm_hits.txt
  exit 1
fi
echo "[verify][ok] no ORM usage detected"

echo "[verify] checking controllers for ST_Distance usage"
if rg -n --glob "*controller.ts" "ST_Distance" "$BACKEND_DIR/src/modules" > /tmp/verify_stdistance_hits.txt; then
  echo "[verify][fail] ST_Distance detected in controller path:"
  cat /tmp/verify_stdistance_hits.txt
  exit 1
fi
echo "[verify][ok] no ST_Distance usage in controllers"

echo "[verify] checking migration file types"
if find "$BACKEND_DIR/migrations" -type f ! -name "*.sql" | grep -q .; then
  echo "[verify][fail] non-SQL migration files detected:"
  find "$BACKEND_DIR/migrations" -type f ! -name "*.sql"
  exit 1
fi
echo "[verify][ok] migrations are SQL-only"

echo "[verify] checking append-only events_log usage"
if rg -n "UPDATE\\s+events_log|DELETE\\s+FROM\\s+events_log" \
  "$BACKEND_DIR/src" "$BACKEND_DIR/migrations" > /tmp/verify_events_log_mutation_hits.txt; then
  echo "[verify][fail] mutation on events_log detected:"
  cat /tmp/verify_events_log_mutation_hits.txt
  exit 1
fi
echo "[verify][ok] events_log is append-only"

echo "[verify][pass] architecture checks passed"
