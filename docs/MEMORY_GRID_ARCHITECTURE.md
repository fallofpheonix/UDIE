# UDIE Memory-Resident Spatial Risk Grid

## Architecture Diagram
```mermaid
flowchart LR
    A[events_log append-only] --> B[projection/lifecycle workers]
    B --> C[risk_cells authoritative storage]
    C --> D[RiskGridService startup hydrate]
    B --> E[incremental risk_cells updates]
    E --> D
    D --> F[/api/risk memory lookup]

    subgraph cold_path[Background / Cold Path]
      B
      E
    end

    subgraph hot_path[Request / Hot Path]
      F
    end
```

## Design Constraints
- `risk_cells` remains authoritative persisted surface.
- `RiskGridService` is an in-memory evaluation cache (`Map<h3_index, weight>`).
- `/api/risk` performs lookup against memory only; no SQL in request path.
- All mutations remain outside hot path.
- Rebuild determinism preserved via `events_log` -> derived state replay.

## Migration Plan
### Phase 1: Schema and Parameters
1. Keep `events_log` unchanged.
2. Keep `risk_cells` schema as authoritative.
3. Add/verify model parameters:
- `GRID_HYDRATE_BATCH_SIZE`
- `GRID_REFRESH_INTERVAL_SECONDS`
- `INTEL_*` thresholds (if intelligence enabled)

### Phase 2: Memory Grid Activation
1. Introduce `RiskGridService` hydrate at startup from `risk_cells`.
2. Add `upsertWeight/updateWeight/getWeight/getAllActiveIndices` APIs.
3. Ensure hydration logs size + timing.

### Phase 3: Incremental Updates
1. On ingestion/projection, update `risk_cells` incrementally (neighbor propagation via H3 ring).
2. Mirror delta into `RiskGridService` (or schedule near-real-time refresh if process isolation requires it).
3. Keep periodic full refresh optional as safety fallback, not hot-path dependency.

### Phase 4: Intelligence Layer
1. Use memory grid + persisted tables to detect:
- hotspots
- sudden spikes
- recurring zones
2. Persist outputs to `intelligence_insights`.
3. Expose `GET /api/intelligence` with optional region filtering.

## Validation Checks
### 1. Memory Grid Consistency
- Sample N cells from `risk_cells`.
- Verify in-memory weight matches persisted weight.
- Failure threshold: any mismatch > tolerance (`1e-9`).

### 2. Rebuild Determinism
- Compute checksum/hash of `risk_cells`.
- Run deterministic rebuild from `events_log`.
- Recompute checksum/hash.
- Must match exactly (or within fixed tolerance if floats).

### 3. Latency Benchmark
- Evaluate synthetic routes through memory grid only.
- Track p50/p95 latency.
- Target: `< 1ms` mean for route evaluation loop.

## Benchmark Harness
Use:
- `/Users/fallofpheonix/Project/UDIE/backend/benchmarks/memory_grid_bench.ts`

Command:
```bash
cd backend
npm run bench:memory-grid
```
