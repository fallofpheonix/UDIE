# UDIE: Current Status

## Sprint 1: Hardening & Determinism (COMPLETED)
UDIE now runs with a hardened ingestion-to-surface pipeline and validated build paths.

### ✅ Completed Milestones
- **Append-Only Log**: `events_log` enforced for ingestion records, with idempotency keys.
- **Lifecycle Engine**: Restart-safe maintenance worker with advisory lock and `system_state` telemetry.
- **Materialization Engine**: Restart-safe risk surface refresh with advisory lock and job-state tracking.
- **Pre-Aggregated Surface**: `/risk` path remains `risk_cells` only.
- **DB-Owned Runtime Constants**: route bounds and sigmoid parameters loaded from `model_parameters`.
- **Verification Tooling**: `validate:rebuild`, `validate:plan`, and `test:risk` checks added.
- **iOS Stability**: API client retry/cancellation handling and improved degradation state.

### 🚧 Immediate Priority: Sprint 2 (Field Validation)
- Validate production-like ingestion volume and regional partition assumptions.
- Finalize real social/civic feed contracts and parser confidence calibration.

### ⚠️ Known Gaps (Managed in Roadmap)
- Real social/civic connector auth + ingestion adapters are still pending.
- Multi-region partition routing remains planned work.
- MapKit route geocoding path has iOS 26 deprecation warnings (non-blocking runtime warning).

## Core Metrics (Baseline)
- **Query Complexity**: $O(route\_cells)$ from `risk_cells` intersection.
- **Refresh Cadence**: 1 minute materialization worker + 15 minute lifecycle worker.
- **Data Integrity**: Deterministic rebuild path implemented via `rebuild_derived_state_from_log()`.
