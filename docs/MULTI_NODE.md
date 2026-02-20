# UDIE Multi-Node Expansion Requirements

Achieve functional horizontal scaling by separating roles while maintaining PostgreSQL as the authoritative source of truth.

## 1. Role Separation (The Trinity Model)
Separate system responsibilities across dedicated nodes:
- **Node A (Ingestion)**: Handles `events_log` arrivals, deduplication, and lifecycle updates (UPDATE-heavy).
- **Node B (Materializer)**: Aggregates `geo_events` into `risk_cells` for specific regions.
- **Node C (Read API)**: Serves `/risk` and `/events` queries.

## 2. Job Coordinator (Advisory Locking)
Use `pg_try_advisory_lock(region_id)` to ensure exactly one materializer is active per region.
- **Pull-Based**: Workers ask for region assignments instead of running on a flat cron.

## 3. Mandatory Write Isolation
All UPDATE-heavy operations (decay, expiry, merge) must terminate exclusively on the primary ingestion node.
- **Read Nodes**: Execute zero writes to prevent buffer churn.

## 4. Streaming Replica Integration
- **Lag Tolerance**: `replication_delay < refresh_interval`.
- **Targeting**: Scale reads by adding replicas, not by sharding the primary (yet).

## 5. Failure & Recovery
- **Automation**: detect incomplete or crashed materialization runs mid-refresh.
- **Safe Resume**: No manual state cleanup required after a node failure.

## 6. The Scale Unit
The smallest deployable "Unit of Intelligence":
- 1x Ingestion Worker
- 1x Materializer
- 1x Read Replica
- N Regional Partitions

"Scaling is adding Units, not reconfiguring the monolith."
