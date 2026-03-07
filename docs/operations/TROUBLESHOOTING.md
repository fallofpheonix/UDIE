# 🛠️ UDIE Troubleshooting Guide

This guide explains how to diagnose and resolve common issues in the Urban Disruption Intelligence Engine (UDIE).

Troubleshooting should always follow this order:
1. **API Health**
2. **Database Connectivity**
3. **Worker Status**
4. **Risk Grid State**
5. **Client Configuration**

⸻

## 🔍 Common Issues

### ❌ Backend Connection Error
**Symptom**: iOS or Web Admin reports "Cannot connect to backend" or "Network request failed".

**Possible Causes**:
- Backend server not running.
- Incorrect API base URL in client.
- Port mismatch (default: 3000).
- Docker database container is stopped.

**Diagnostic Steps**:
1. Verify backend process: `lsof -i :3000`
2. Check API liveness: `curl http://localhost:3000/api/v1/health/live`
   - *Expected: `{"status":"ok"}`*
3. Verify readiness: `curl http://localhost:3000/api/v1/health/ready`

**Fix**:
- Restart backend: `npm run start:dev`
- Check iOS environment: `UDIE_API_BASE_URL=http://localhost:3000/api/v1`

⸻

### ❌ Zero Risk Scores
**Symptom**: Routes always return `riskScore = 0` and `riskLevel = LOW`, even with active disruptions.

**Possible Causes**:
- Materialization worker stopped.
- `risk_cells` table is empty.
- In-memory risk grid hydration failure.
- `events_active` pipeline stalled.

**Diagnostic Steps**:
1. Check risk surface: `SELECT COUNT(*) FROM risk_cells;`
2. Check active events: `SELECT COUNT(*) FROM events_active;`
3. Verify worker heartbeat: `curl http://localhost:3000/api/v1/health/ready`
   - *Look for `materialization_worker` status: `healthy`*

**Fix**:
- Restart workers: `npm run start:workers`
- Force rebuild: `npm run validate:rebuild`

⸻

### ❌ Database Connection Failure
**Symptom**: Backend logs show `ECONNREFUSED` or "database connection failed".

**Possible Causes**:
- Docker Desktop not running.
- `udie-postgres` container stopped.
- `DATABASE_URL` misconfigured in `.env`.

**Diagnostic Steps**:
1. Check Docker status: `docker ps`
2. Check container logs: `docker logs udie-postgres`

**Fix**:
- Start database: `docker compose up -d`

⸻

### ❌ PostGIS or H3 Extension Missing
**Symptom**: SQL errors like `function h3_to_geo does not exist` or `function ST_Distance does not exist`.

**Cause**: Extensions were not initialized or migrations failed.

**Fix**:
- Recreate container: `docker compose down && docker compose up --build`
- Verify extensions in psql:
  ```sql
  SELECT PostGIS_Full_Version();
  SELECT h3_version();
  ```

⸻

### ❌ Architecture Integrity Failure
**Symptom**: Architecture diagnostics report failures or drift.

**Diagnostic Steps**:
- Query endpoint: `curl http://localhost:3000/api/v1/diagnostics/architecture`
   - *Checks for: query plan drift, worker lag, risk grid staleness.*

**Fix**:
- Trigger deterministic rebuild: `npm run validate:rebuild`
- Re-run architecture audit.

⸻

## 📜 Log Locations

- **Backend**: Primary output in `stdout`. High-detail traces in `system_errors` table.
- **Docker**: `docker logs udie-postgres` for database-level issues.
- **iOS**: Xcode Debug Console. Look for `[APIClient]` or `[RiskGrid]` tags.

⸻

## 🚀 Quick Diagnostic Checklist
1. [ ] Backend process running?
2. [ ] Database container active?
3. [ ] Migrations applied?
4. [ ] Workers healthy/Materialization active?
5. [ ] `risk_cells` populated?
6. [ ] API reachable from client?

⸻

## 💡 Professional Debugging Habits (The SRE Way)

1. **Verify Infrastructure First**: 80% of "code bugs" are actually container/network failures. Always run `scripts/diagnose-udie.sh` first.
2. **Reproduction Before Fixing**: Never attempt to fix a bug you haven't reproduced and recorded. (Mandatory for UDIE agents).
3. **Evidence Over Intuition**: If it’s not in the logs or a `curl` response, it didn't happen.
4. **Isolate the Failure Class**: Is it **NETWORK**, **SCHEMA**, or **WORKER**? Classification speeds up resolution by 5x.
5. **Check Environment Context**: Are you connecting to `localhost` from a physical device? Check your `ifconfig`.
6. **Follow the Request Lifecycle**: Trace the event from Ingestion -> Bus -> Materialization -> Cache -> API.
7. **Maintain the Specification**: Always update the documentation after fixing a drift. Specifications are the "First Idea."

---

## 🚫 Common Beginner Mistakes to Avoid

- **Hardcoding Localhost**: Physical iPhones cannot see your Mac's `localhost`. Use your LAN IP (e.g., `192.168.1.5`).
- **Ignoring Healthchecks**: Starting the backend before Postgres is ready. (UDIE's `docker-compose.yml` handles this via `depends_on`).
- **API Prefix Mismatch**: Calling `/api/events` when the backend serves `/api/v1/events`.
- **Querying Raw Events**: Don't calculate risk from raw events in the API request path; use the precomputed `risk_grid`.
- **Ignoring Temporal Decay**: Letting risk weights accumulate forever until the map is permanently "saturated."
- **Mixing Roles**: Don't put business logic in controllers. Keep them thin and delegate to services.

---

MIT © 2026 **UDIE Engineering Group**. 
"If you can't measure it, you can't model it."
