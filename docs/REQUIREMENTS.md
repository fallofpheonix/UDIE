# UDIE System Requirements

This document defines the constraints and goals of the UDIE spatial intelligence substrate.

## Functional Requirements
- **Risk Scoring**: Provide weighted risk scores for arbitrary routes within 50km.
- **Event Lifecycle**: Automate the rise, plateau, and decay of urban disruptions.
- **Ingestion Integrity**: Every incoming report must be logged immutably.
- **Deduplication**: Merging multi-source reports of the same incident (25m/30min radius).
- **Spatial Transparency**: Provide justifications for risk levels via event counts and contributing cells.

## Performance Requirements
- **Query Complexity**: must stay $O(route\_cells)$. Latency must be independent of total historical events.
- **Refresh SLA**: Materialization refresh must complete within 25% of the refresh interval.
- **Concurrent Load**: System must support ingestion spikes without degrading query latency.

## Operational Requirements
- **Determinism**: The system must be 100% rebuildable from the raw logs at any time.
- **Observability**: Every job must track duration and status in `system_state`.
- **Scaling Axis**: Geography. The system must partition by H3 cells to allow horizontal scale.
- **Safety**: Bounding input route complexity (vertices/length) to prevent resource exhaustion.

## Data Model Invariants
- **Log of Truth**: All state is derived from `events_log`.
- **Decaying Confidence**: No data point in the active set is permanent.
- **Bucketed Read Path**: The hot path NEVER scans raw geometries; it only joins pre-aggregated cells.
