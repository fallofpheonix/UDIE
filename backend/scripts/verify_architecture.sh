#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[verify] 1/4 benchmark replay"
bash ./scripts/benchmark_replay.sh

echo "[verify] 2/4 forbidden ORM scan"
if rg -n "@prisma/client|typeorm|sequelize|mikro-orm" src; then
  echo "[verify][fail] ORM dependency detected in src"
  exit 2
fi

echo "[verify] 3/4 request-time spatial anti-pattern scan"
if rg -n "ST_Distance\(|ST_DWithin\(" src/modules -g"*controller.ts"; then
  echo "[verify][fail] spatial distance call detected in controller"
  exit 3
fi

echo "[verify] 4/4 migration format check"
BAD_MIGRATIONS=$(find migrations -maxdepth 1 -type f | grep -Ev '\\.sql$' || true)
if [[ -n "${BAD_MIGRATIONS}" ]]; then
  echo "[verify][fail] non-SQL migration files found"
  echo "$BAD_MIGRATIONS"
  exit 4
fi

echo "[verify][pass] architecture checks passed"
