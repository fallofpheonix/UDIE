# ⏱️ 10-Minute Distributed Systems Debugging Workflow

This is the standard UDIE protocol for diagnosing failures across the substrate in under 10 minutes.

---

## Phase 1: The 60-Second Pulse (Infra Check)
**Goal**: Is the engine actually alive?
1. Execute `./scripts/diagnose-udie.sh`.
2. Verify all containers are `healthy` (Wait for Postgres healthcheck).
3. If containers are missing, run `cd infra && docker-compose up -d`.

## Phase 2: The 3-Minute Contract Discovery (API Check)
**Goal**: Is the client talking to the correct backend version?
1. Run `./scripts/agent-bootstrap.sh`.
2. Check the detected `API_PREFIX` (e.g., `/api/v1`).
3. If prefix mismatch detected, update the mobile client configuration.
4. Verify `/health/ready` returns `{ "status": "ok" }`.

## Phase 3: The 5-Minute Data Audit (Projection Check)
**Goal**: Is the risk grid hydrated?
1. Run `scripts/classify-failure.sh`.
2. Check for **SCHEMA_DRIFT** or **PROJECTION_LAG**.
3. Run `SELECT count(*) FROM risk_cells;` in Postgres.
4. If empty, trigger `curl /diagnostics/rebuild`.

## Phase 4: The 8-Minute Worker Trace (Logic Check)
**Goal**: Is the kernel active?
1. Check `docker logs udie-backend | grep -i risk`.
2. Look for "Materialization Worker Heartbeat".
3. Check Prometheus `/metrics` for `udie_event_ingestion_total`.

## Phase 5: The Final 10-Minute Resolution
1. **If NETWORK**: Check physical device IP vs. Mac IP.
2. **If WORKER**: Restart the specific worker partition.
3. **If SCHEMA**: Run `npm run migration:run`.

---

### Invariant: The "Evidence First" Rule
No developer is authorized to suggest a code change without a **Reproduction Log** gathered during this 10-minute window.
