#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/engine-backend"
if [[ -f "${ROOT_DIR}/infra/docker-compose.yml" ]]; then
  COMPOSE_FILE="${ROOT_DIR}/infra/docker-compose.yml"
elif [[ -f "${BACKEND_DIR}/docker-compose.yml" ]]; then
  COMPOSE_FILE="${BACKEND_DIR}/docker-compose.yml"
else
  echo "[diagnose] ERROR: docker compose file not found under infra/ or engine-backend/"
  exit 1
fi
REPORT_FILE="${ROOT_DIR}/SYSTEM_DIAGNOSTIC_REPORT.md"

API_HEALTH_URL_PRIMARY="${API_HEALTH_URL_PRIMARY:-http://localhost:3000/api/v1/health}"
API_HEALTH_URL_FALLBACK="${API_HEALTH_URL_FALLBACK:-http://localhost:3000/api/health}"
API_ARCH_URL_PRIMARY="${API_ARCH_URL_PRIMARY:-http://localhost:3000/api/v1/diagnostics/architecture}"
API_ARCH_URL_FALLBACK="${API_ARCH_URL_FALLBACK:-http://localhost:3000/api/diagnostics/architecture}"
API_DASH_BBOX="${API_DASH_BBOX:-minLat=28.60&maxLat=28.70&minLng=77.10&maxLng=77.30}"
API_DASH_URL_PRIMARY="${API_DASH_URL_PRIMARY:-http://localhost:3000/api/v1/city-dashboard?${API_DASH_BBOX}}"
API_DASH_URL_FALLBACK="${API_DASH_URL_FALLBACK:-http://localhost:3000/api/city-dashboard?${API_DASH_BBOX}}"

DATABASE_URL="${DATABASE_URL:-postgresql://udie:udie@localhost:5432/udie}"

STATUS_BUILD="FAIL"
STATUS_TEST="FAIL"
STATUS_DOCKER="FAIL"
STATUS_CONTAINERS="FAIL"
STATUS_DB="FAIL"
STATUS_MIGRATIONS="FAIL"
STATUS_REBUILD="FAIL"
STATUS_PLAN="FAIL"
STATUS_HEALTH="FAIL"
STATUS_ARCH="FAIL"
STATUS_DASH="FAIL"

log() {
  printf '[diagnose] %s\n' "$*"
}

run_check() {
  local label="$1"
  shift
  log "$label"
  "$@"
}

http_check() {
  local url="$1"
  curl -sS -f "$url" >/tmp/udie_diag_resp.json
}

http_check_with_fallback() {
  local primary="$1"
  local fallback="$2"
  if http_check "$primary"; then
    printf '%s' "$primary" >/tmp/udie_diag_url.txt
    return 0
  fi
  http_check "$fallback"
  printf '%s' "$fallback" >/tmp/udie_diag_url.txt
}

wait_for_http() {
  local url="$1"
  local attempts="${2:-30}"
  local sleep_seconds="${3:-2}"
  local i
  for i in $(seq 1 "$attempts"); do
    if curl -sS -f "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_seconds"
  done
  return 1
}

log "UDIE SYSTEM DIAGNOSTIC START"
log "root=${ROOT_DIR}"
log "backend=${BACKEND_DIR}"
log "compose=${COMPOSE_FILE}"

if [[ ! -d "$BACKEND_DIR" ]]; then
  log "ERROR: backend directory not found: $BACKEND_DIR"
  exit 1
fi

pushd "$BACKEND_DIR" >/dev/null

run_check "Repository state" git status --short

run_check "Installing dependencies" npm install --no-audit --no-fund >/dev/null

run_check "Building backend" npm run build >/dev/null
STATUS_BUILD="PASS"

run_check "Running risk tests" npm run test:risk >/dev/null
STATUS_TEST="PASS"

run_check "Checking Docker daemon" docker info >/dev/null
STATUS_DOCKER="PASS"

run_check "Starting Docker services" docker compose -f "$COMPOSE_FILE" up -d >/dev/null

run_check "Checking container status" docker compose -f "$COMPOSE_FILE" ps
STATUS_CONTAINERS="PASS"

export DATABASE_URL

run_check "Checking database connectivity" psql "$DATABASE_URL" -c 'select 1;' >/dev/null
STATUS_DB="PASS"

if psql "$DATABASE_URL" -Atqc "SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='events_log'" | rg -q '^1$'; then
  log "Migrations already present (events_log exists); skipping replay"
else
  run_check "Applying migrations" npm run migration:up >/dev/null
fi
STATUS_MIGRATIONS="PASS"

run_check "Running rebuild validation" npm run validate:rebuild >/dev/null
STATUS_REBUILD="PASS"

run_check "Running query plan validation" npm run validate:plan >/dev/null
STATUS_PLAN="PASS"

run_check "Waiting for backend readiness" wait_for_http "$API_HEALTH_URL_PRIMARY" 40 2

run_check "Checking health endpoint" http_check_with_fallback "$API_HEALTH_URL_PRIMARY" "$API_HEALTH_URL_FALLBACK"
STATUS_HEALTH="PASS"
HEALTH_URL_USED="$(cat /tmp/udie_diag_url.txt)"

run_check "Checking architecture diagnostics endpoint" http_check_with_fallback "$API_ARCH_URL_PRIMARY" "$API_ARCH_URL_FALLBACK"
STATUS_ARCH="PASS"
ARCH_URL_USED="$(cat /tmp/udie_diag_url.txt)"

run_check "Checking city dashboard endpoint" http_check_with_fallback "$API_DASH_URL_PRIMARY" "$API_DASH_URL_FALLBACK"
STATUS_DASH="PASS"
DASH_URL_USED="$(cat /tmp/udie_diag_url.txt)"

popd >/dev/null

cat > "$REPORT_FILE" <<REPORT
# UDIE System Diagnostic Report

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Summary

| Check | Status |
|---|---|
| Build | $STATUS_BUILD |
| Risk tests | $STATUS_TEST |
| Docker daemon | $STATUS_DOCKER |
| Containers | $STATUS_CONTAINERS |
| Database connectivity | $STATUS_DB |
| Migrations | $STATUS_MIGRATIONS |
| Rebuild validation | $STATUS_REBUILD |
| Query plan validation | $STATUS_PLAN |
| Health endpoint | $STATUS_HEALTH |
| Architecture diagnostics endpoint | $STATUS_ARCH |
| City dashboard endpoint | $STATUS_DASH |

## Endpoints

- Health: ${HEALTH_URL_USED:-N/A}
- Architecture diagnostics: ${ARCH_URL_USED:-N/A}
- City dashboard: ${DASH_URL_USED:-N/A}

## Notes

- This report fails-fast during execution; a missing PASS indicates where execution stopped.
- DATABASE_URL used: $DATABASE_URL
REPORT

log "UDIE SYSTEM DIAGNOSTIC COMPLETE"
log "Report written: $REPORT_FILE"
