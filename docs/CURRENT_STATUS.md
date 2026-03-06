# UDIE: Current Status

## Sprint 1: Hardening & Determinism (COMPLETED)
UDIE runs with hardened ingestion-to-surface flow and bounded request-time risk evaluation.

### ✅ Completed Milestones
- **API Versioning**: Global `/api/v1` prefix and split health endpoints implemented.
- **Validation Guards**: Spatial bounding and vertex limiting guards active.
- **Risk Engine v4**: Segmentization and length-based normalization operational.
- **Operational Hardening**: Soft-locks, heartbeat monitoring, and log retention implemented.
- **Parameter Versioning**: Historical tracking for scoring constants enabled.
- **Telemetry**: Lock wait and replica lag monitored in `/ready` health check.
- **Pre-Aggregated Surface**: `/risk` path remains `risk_cells` only.
- **In-Memory Risk Grid**: `risk_cells` hydrates into `RiskGridService` for sub-ms lookup path.
- **Density Amplification**: aggregation applies `1 + alpha * log(1 + N)` with DB-configured `DENSITY_ALPHA`.
- **Time-Lapse Surface**: periodic `risk_snapshots` and `/risk-snapshots` API are implemented.
- **City Intelligence APIs**: `/city-dashboard` and `/cell-insight` endpoints implemented.
- **Route Comparison API**: `/route-options` implemented with bounded utility scoring using memory-risk evaluation.
- **Forecast Surface**: `forecast_cells` smoothing model (`forecast_30m`, `forecast_60m`) implemented.
- **DB-Owned Runtime Constants**: route bounds and sigmoid parameters loaded from `model_parameters`.
- **Verification Tooling**: `validate:rebuild`, `validate:plan`, and `test:risk` checks added.
- **iOS Stability**: API client retry/cancellation handling and improved degradation state.

### 🚧 Immediate Priority
- Run DB-backed validation suite in environment with `DATABASE_URL` configured.
- Add benchmark assertions for hotspot clustering and density amplification band stability.
- Resolve local infrastructure blocker: Docker daemon unavailable on host prevented `validate:rebuild` and `validate:plan`.

### ⚠️ Known Gaps (Managed in Roadmap)
- Real social/civic connector auth + ingestion adapters are still pending.
- Multi-region partition routing remains planned work.
- MapKit route geocoding path has iOS 26 deprecation warnings (non-blocking runtime warning).

## Core Metrics (Current)
- **Query Complexity**: $O(route\_cells)$ from `risk_cells` intersection.
- **Refresh Cadence**: snapshot worker every 5 minutes; materialization/lifecycle workers remain scheduled.
- **Data Integrity**: Deterministic rebuild path implemented via `rebuild_derived_state_from_log()`.
