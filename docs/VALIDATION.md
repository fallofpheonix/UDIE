# UDIE Verification & Validation

This guide defines how we prove that UDIE is both technically correct and scientifically accurate.

## 1. Architectural Scaling (O(cells))
- **Experiment**: Scale Proof. Doubling total event count must not increase `/risk` latency.
- **Success**: Latency delta < 3%.
- **Command**: `ts-node benchmarks/scale_test.ts`

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
- **Goal**: Core areas must not perpetually saturate at "HIGH". Requires localized normalization metrics.

## 8. Duplication Resistance
- **Experiment**: 100-report burst for one incident.
- **Success**: Logarithmic confidence reinforcement, not linear explosion.
- **Command**: replay same payload with same idempotency key and verify `DUPLICATE`.

## 9. Query Plan Guard
- **Experiment**: Ensure `/risk` hot path avoids raw event scans.
- **Target**: no `Seq Scan on geo_events` in explain output.
- **Command**: `npm run validate:plan`

---

## The Evaluation Harness
All verification must run through the automated `benchmarks/spatial_baseline_v1` dataset to ensure regressions are identified instantly.
