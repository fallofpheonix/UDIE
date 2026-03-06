# UDIE Verification & Validation

This guide defines how we prove that UDIE is both technically correct and scientifically accurate.

## 1. Architectural Scaling (O(cells))
- **Experiment**: Scale Proof. Doubling total event count must not increase `/risk` latency.
- **Success**: Latency delta < 3%.
- **Command**: `ts-node benchmarks/scale_test.ts`

## 1.1 Hot Path Latency
- **Experiment**: In-memory route scoring path.
- **Success**: Median route evaluation below 1 ms under benchmark dataset.
- **Command**: `npm run test:risk`

## 2. Model Fidelity (The Real World)
- **Experiment**: Ground Truth Correlation.
- **Action**: Compare `system_score` against verified news reports.
- **Metric**: Positive correlation between score and real-world impact duration.

## 3. Sensitivity Testing ($\lambda$)
- **Experiment**: Vary the decay rate ($100m$ to $1000m$).
- **Success**: Risk category (Low/High) must remain stable under small parameter shifts.

## 4. Temporal Pulse
- **Experiment**: Rise-Plateau-Decay cycle.
- **Goal**: Simulated events must disappear automatically within the refresh SLA after they stop being reported.

## 5. Spatial Stability
- **Experiment**: 30m route shift test.
- **Success**: Minimal score swing. Prevents "fragile" risk scoring near cell boundaries.

## 6. Stress Rebuild
- **Experiment**: Deterministic Rebuild.
- **Action**: `Drop Derived` -> `Replay Log` -> `Diff Results`.
- **Target**: Zero delta between original and rebuilt state.
- **Command**: `npm run validate:rebuild`

## 7. Density Stress
- **Experiment**: Urban core vs Sparse outskirts.
- **Goal**: Core areas must not perpetually saturate at "HIGH". Density amplification must remain bounded and stable.
- **Model**: `density_factor = 1 + alpha * log(1 + neighbor_event_count)` with `alpha` from `model_parameters`.
- **Guardrail**: apply configured cap (`DENSITY_FACTOR_MAX`) during materialization.

## 8. Duplication Resistance
- **Experiment**: 100-report burst for one incident.
- **Success**: Logarithmic confidence reinforcement, not linear explosion.
- **Command**: replay same payload with same idempotency key and verify `DUPLICATE`.

## 9. Query Plan Guard
- **Experiment**: Ensure `/risk` hot path avoids raw event scans.
- **Target**: no `Seq Scan on geo_events` in explain output.
- **Command**: `npm run validate:plan`

## 9.1 Architecture Audit
- **Experiment**: run invariant checks via diagnostics service.
- **Target**: healthy status for query-plan, rebuild, partition, and hot-path checks.
- **Command**: `npm run verify:architecture` and `GET /api/v1/diagnostics/architecture`

## 10. Snapshot Surface Validation
- **Experiment**: Verify 5-minute snapshot cadence and bounded retrieval.
- **Action**: ensure `risk_snapshots` row count grows monotonically and `/risk-snapshots` response obeys bbox+time filters.
- **Command**: run snapshot worker and query `/api/v1/risk-snapshots`.

## 11. Performance Sentinel
- **Experiment**: collect periodic performance state.
- **Target**: risk latency average within threshold and healthy buffer hit ratio.
- **Source**: `system_state.performance_sentinel`.

## 12. Simulation Isolation
- **Experiment**: inject synthetic events through simulation API.
- **Target**: no mutation to `events_log`/`risk_cells` from simulation stream.
- **Command**: `POST /api/v1/simulation/events` then verify production tables unchanged.

---

## The Evaluation Harness
All verification must run through the automated `benchmarks/spatial_baseline_v1` dataset to ensure regressions are identified instantly.

## Runtime Prerequisite
- `validate:rebuild` and `validate:plan` require `DATABASE_URL` in environment.
