# UDIE Operational Requirements

UDIE must operate as a managed service with bounded costs and observable health.

## 1. Managed Background Jobs
All background logic (refresh, decay, merge) must be formalized as managed workers.
- **Monitoring**: Emit start/finish/duration logs.
- **Safety**: Atomic transactions; fail safely without partial writes.

## 2. State Visibility (`system_state`)
A internal telemetry table to track component health.
```sql
CREATE TABLE system_state (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Current keys:
- `lifecycle`
- `materialization`

## 3. Refresh Isolation
The risk surface materialization (`risk_cells`) must use snapshot isolation.
- **Goal**: Reads never block writes; writes never block reads.
- **Verification**: Concurrent event ingestion during materialization.
- **Implementation**: Background refresh guarded by advisory lock (`pg_try_advisory_lock`).

## 4. Ingestion Rate Smoothing (Batching)
To prevent WAL and index churn during spikes.
- **Contract**: Batch per 100 events or 1.0s window before database commit.

## 5. Storage Growth & Cold-Start
- **Automation**: System must automatically rebuild `risk_cells` if missing or stale on boot.
- **Monitoring**: Daily growth alerts for `events_log` and indices.

## 6. Freshness SLA
- **Definition**: The maximum allowable delay from real-world event ingestion to reflection in the `/risk` surface.
- **Target**: To be established during Spirit 2 validation.

## 7. Spatial Hotspot Mitigation
Prevent localized report spam from distorting the risk field by collapsing overloaded cells into synthetic weighted entries.
