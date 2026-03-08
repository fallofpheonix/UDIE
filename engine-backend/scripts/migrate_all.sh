#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required"
  exit 1
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
for file in "$repo_root"/migrations/*.sql; do
  [[ -e "$file" ]] || continue
  echo "[MIGRATE] applying $(basename "$file")"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file"
done
