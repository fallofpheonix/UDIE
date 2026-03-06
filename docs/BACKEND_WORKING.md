# Backend Working (UDIE)

## 1. What the Backend Does
UDIE backend is a NestJS + PostgreSQL/PostGIS system that computes route disruption risk using a pre-aggregated spatial surface.

It exposes only three runtime APIs:
- `GET /api/health`
- `GET /api/events`
- `POST /api/risk`

Core principle:
- Request path reads precomputed data (`risk_cells`) and active projection (`active_geo_events`).
- Raw observations are appended to `events_log` and then projected/materialized by background SQL logic.

---

## 2. High-Level Data Flow

```text
Raw signal/report
  -> IngestionService
  -> INSERT events_log (append-only)
  -> upsert_geo_event_v2(...) projection update
  -> geo_events / active_geo_events
  -> refresh_risk_surface() materialization
  -> risk_cells
  -> /api/risk and /api/events reads
```

There are two periodic workers:
- Lifecycle worker: decays confidence, expires stale active events.
- Materialization worker: refreshes `risk_cells` for fast route scoring.

Both workers use PostgreSQL advisory locks to remain restart-safe and avoid concurrent duplicate work.

---

## 3. How Data Is Fetched

## 3.1 `GET /api/events`
Controller -> service -> repository query.

Fetch pattern:
- Input: map bounding box (`minLat`, `maxLat`, `minLng`, `maxLng`) + optional filters.
- Query source: `active_geo_events` (view over active lifecycle state).
- Spatial operator: `ST_Intersects` with bounding envelope.
- Output: event points for map rendering.

Why this is fast:
- Reads only current active state, not full history.
- Uses spatially bounded region query.

## 3.2 `POST /api/risk`
Controller -> `RiskService.calculateRouteRisk(...)`.

Fetch pattern:
- Input: route polyline coordinates + city.
- Service validates request bounds (vertex count, approximate distance) from DB-backed model parameters.
- Route converted to WKT linestring.
- Executes SQL function `calculate_route_risk_v3(ST_GeogFromText(...))`.
- Function intersects route-neighbor cells with `risk_cells` and applies distance decay weighting.
- Returns normalized score + risk level + contributing count.

Why this is fast:
- Operates on materialized cell weights (`risk_cells`), not scanning raw event history.
- Query complexity scales with route cell coverage, not total logged events.

## 3.3 `GET /api/health`
- Checks DB connection (`SELECT 1`).
- Reads freshness from `risk_cells.updated_at`.
- Returns `ok` or `degraded` depending on staleness threshold from `model_parameters`.

---

## 4. Background Processing

## 4.1 Ingestion
- Service validates incoming event payload.
- Builds deterministic idempotency key.
- Writes to `events_log` (`INGESTED`, `PROCESSED`, `FAILED` log types).
- Runs projection function (`upsert_geo_event_v2`) to update active disruption state.

## 4.2 Lifecycle Worker
- Runs on schedule.
- Acquires advisory lock (`pg_try_advisory_lock`).
- Executes lifecycle SQL (`run_lifecycle_maintenance()`) for decay + expiry.
- Writes operational status to `system_state`.

## 4.3 Materialization Worker
- Runs every minute.
- Acquires advisory lock.
- Executes `refresh_risk_surface()`.
- Writes success/failure telemetry into `system_state`.

---

## 5. Advantages
1. Deterministic architecture
- History is retained in append-only `events_log` and derived layers can be rebuilt.

2. Request-path performance
- `/risk` uses pre-aggregated `risk_cells`, reducing request-time spatial load.

3. Operational safety
- Advisory locking prevents duplicate cron work after restarts or multi-instance runs.

4. Clear bounded APIs
- Small surface (`/health`, `/events`, `/risk`) simplifies validation and observability.

5. Strong SQL visibility
- Direct SQL avoids hidden ORM query plans in hot paths.

---

## 6. Disadvantages / Trade-offs
1. Materialization lag
- Risk surface is near-real-time, not strictly immediate; freshness depends on worker cadence.

2. Operational dependency on workers
- If lifecycle/materialization jobs fail, data quality and freshness degrade even if API is up.

3. SQL-centric maintenance cost
- Complex logic in SQL functions requires stronger DB expertise and migration discipline.

4. Added pipeline complexity
- Ingestion -> projection -> materialization introduces more moving parts than direct CRUD reads.

5. Environment sensitivity
- Local reproducibility depends on Docker/DB/Xcode/toolchain health, not only code correctness.

---

## 7. Practical Summary
UDIE backend is designed as a log-driven spatial risk engine:
- append observations,
- maintain active state with lifecycle decay,
- materialize a risk surface,
- serve thin, bounded APIs with predictable query behavior.

This favors correctness and scalable request latency over minimal implementation complexity.
