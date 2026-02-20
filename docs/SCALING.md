# UDIE Scaling Readiness Requirements

Scale must be achieved by ensuring spatial workload can be partitioned cleanly by geography.

## 1. Spatial Partitioning (Logical Split)
Both `events_active` and `events_log` must be partitioned by an H3 Parent cell at a coarser resolution (e.g., Res 6).
- **Mechanism**: `PARTITION BY LIST (h3_parent)`.
- **Goal**: Queries touch only the relevant geographic partition (Partition Pruning).

## 2. Localized Risk Surface
Risk materialization must not be global.
- **Rule**: Every geographic partition maintains its own local `risk_cells` surface.
- **Benefits**: Parallel, independent, and concurrent refresh cycles.

## 3. Read Isolation
Introduce dedicated read-replicas early.
- **Primary**: Ingestion, Aggregation, Real-time Risk scoring.
- **Replica**: UI event fetches (`/events`), Analytics, Debugging.

## 4. Geographic API Scoping
The API gateway must resolve geographic region before hitting the database.
- **Contract**: `request -> resolve parent h3 -> scoped query`. unscoped spatial queries are prohibited.

## 5. Cross-Partition Independence
Simulation must confirm that heavy load in one region (e.g., Delhi) has zero impact on latency or resource access in another region (e.g., Bangalore).

## 6. Region-Aware Caching
Cache keys must include the region dimension: `risk:{region}:{h3_cell}`.

## 7. Scaling Envelope (Unit of Growth)
Instead of sizing a monolith, define the unit of growth as a Region.
- **Envelopes**: Max events, max refresh cost, max queries per region.
- **Expansion**: "Scaling" is the addition of a new city partition + dedicated worker.
