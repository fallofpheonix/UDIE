# UDIE Evaluation Harness

The Evaluation Harness is the laboratory for validating the spatial risk field. It ensures that system improvements do not regress model accuracy or scaling.

## 1. The Benchmark Dataset
Located at `/backend/benchmarks/spatial_baseline_v1`.
- **Contents**: 100 verified incidents, 50 canonical routes, 3 urban density regions (Core, Transit, Outskirts).

## 2. Golden Outputs
Stored reference results for the benchmark dataset.
- **Metrics**: Score, Contributing Cell count, CPU ms consumed.
- **Baseline**: Current system state (v2) serves as the golden reference.

## 3. Replay Runner (`benchmark_replay.sh`)
Automated verification pipeline:
1. `Truncate derived tables`
2. `Load benchmark log`
3. `Run materialization refresh`
4. `Execute benchmark routes`
5. `Diff against Golden Outputs`

Current automation scripts:
- `/backend/scripts/validate_rebuild.sh`
- `/backend/scripts/check_risk_query_plan.sh`

## 4. Drift Tolerance
- **Score Delta**: $\le 3\%$
- **Latency Delta**: $\le 10\%$
- **Efficiency Delta**: $0\%$ (Increase in cells scanned is a REJECT).

## 5. Visualization
The harness generates:
- Risk score distribution plots.
- Refresh duration histograms.
- Spatial efficiency heatmaps (Events Scanned / Total Events).
