# Urban Pattern Intelligence Module

## Position in UDIE Architecture
```mermaid
flowchart TD
    A[events_log] --> B[projection/lifecycle]
    B --> C[risk_cells]
    C --> D[RiskGridService memory grid]
    D --> E[IntelligenceWorker async]
    E --> F[intelligence_events append-only]
    E --> G[intelligence_insights read-model]
    G --> H[GET /api/intelligence]

    C --> I[/api/risk]
```

## Asynchronous Contract
- Intelligence computations run only in background worker (`cron every 2 minutes`).
- `/api/intelligence` reads persisted output tables only.
- `/api/risk` remains isolated from intelligence computation.

## Determinism Contract
- `intelligence_events` is append-only audit stream.
- `intelligence_insights` is disposable/read-optimized projection.
- Full intelligence state is reproducible from:
  - `events_log`
  - deterministic thresholds from `model_parameters`
  - deterministic rule functions.

## Detection Thresholds (DB-backed)
- `INTEL_HOTSPOT_THRESHOLD`
- `INTEL_HOT_NEIGHBORS_MIN`
- `INTEL_SPIKE_MULTIPLIER`
- `INTEL_SPIKE_WINDOW_MINUTES`
- `INTEL_RECURRING_EVENTS_24H`
- `INTEL_SCAN_LIMIT`

## Pattern Detection Pipeline
1. Read active H3 cells from in-memory grid.
2. Hotspot rule:
   - high cell weight + dense high-risk neighbors.
3. Spike rule:
   - compare current cell weight vs persisted prior snapshot.
4. Recurring rule:
   - count repeated disruptions in historical window.
5. Persist event records to `intelligence_events`.
6. Build or refresh read-model (`intelligence_insights`).

## Evaluation Harness
Use benchmark/eval scripts:
- `npm run bench:intelligence`
- `npm run bench:memory-grid`

Gate checks:
- threshold load check
- pattern distribution check (24h)
- explain-plan check for intelligence endpoint query
- no request path coupling with intelligence worker
