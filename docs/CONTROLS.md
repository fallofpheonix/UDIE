# UDIE Engineering Discipline

To prevent spatial rot, these three checks must be executed every week without exception.

## 1. Query Plan Audit (`EXPLAIN ANALYZE`)
Inspect the `/risk` query path.
- **Requirement**: No sequential scans on `geo_events`.
- **Requirement**: Use of `risk_cells_pkey` and index-only scans.
- **Failure**: Any geometry-distance calculation in the hot path.

## 2. Log-Rebuild Replay
Simulate a total disaster and regeneration.
- **Requirement**: Recompute state from `events_log`.
- **Requirement**: Compare risk outputs.
- **Failure**: Out-of-spec divergence between live and rebuilt data.

## 3. Confidence Decay Drift
Audit the aging of data.
- **Requirement**: Ensure $confidence(t+1) < confidence(t)$ for unreinforced events.
- **Requirement**: Check `active_events / total_events` ratio stability.
- **Failure**: Rising average risk during periods of low urban activity.

"UDIE is not built; it is maintained."
