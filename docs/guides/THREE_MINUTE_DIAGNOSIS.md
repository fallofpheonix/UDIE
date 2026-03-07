# ⚡ 3-Minute Fast-Path Diagnosis Protocol

This is the emergency response sequence used by senior engineers to isolate UDIE substrate failures in under 180 seconds.

---

## Minute 1: The Runtime Heartbeat (`60s`)
**Goal**: Confirm the substrate is physically present.
1. Run `docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"`.
2. **If containers missing**: `cd infra && docker-compose up -d`.
3. **If containers unhealthy**: `docker restart <name>`.
*Stop here if infra is dead.*

## Minute 2: The Logic Pulse (`120s`)
**Goal**: Confirm the application is responding.
1. Run `curl -s http://localhost:3000/api/v1/health`.
2. **If 404/Connection Refused**: Execute `./scripts/agent-bootstrap.sh`.
3. Check the discovered `API_PREFIX`. Compare with your latest request.
*Stop here if API contract is broken.*

## Minute 3: The Data Flux (`180s`)
**Goal**: Confirm the state projection is valid.
1. Run `./scripts/classify-failure.sh`.
2. Inspect the **Failure Class**.
3. **If SCHEMA_DRIFT**: `docker logs udie-backend | grep "does not exist"`.
4. **If WORKER_FAILURE**: `docker logs udie-backend | grep -i "failed"`.
*Final Action: If root cause found, update the incident log and propose the fix.*

---

## 🚫 The "Golden Rule" of Fast-Path
**Never restart the backend until you have read the last 50 lines of logs.**
The logs tell you *why* it failed; a restart just hides the symptom.

---

MIT © 2026 **UDIE Engineering Group**. 
"Speed is a byproduct of precision."
