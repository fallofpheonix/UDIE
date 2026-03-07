# 💾 UDIE Data Model & Schema (v2.0)

This document defines the database schema and caching substrate for UDIE. The architecture follows a **Log-Derived Pattern**, where the Event Log is the immutable source of truth and all operational states (PostGIS views, Redis grids) are derived projections.

---

## 🧱 1. Authoritative Persistence (PostgreSQL + PostGIS)

### 1.1 `events_log` (The Source of Truth)
Append-only ledger of all incoming signals. **Strictly Immutable.**
- **Sharding**: Partitioned by `observed_at` (Temporal) and `region_id` (Spatial).
- **Invariants**: No `UPDATE` or `DELETE` operations permitted.

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID (PK)` | Event identifier |
| `coordinate` | `GEOGRAPHY(Point, 4326)` | Precise spatial location |
| `h3_index` | `BIGINT` | H3 resolution 9 mapping |
| `observed_at` | `TIMESTAMP` | Event timestamp |
| `weight` | `DOUBLE` | Raw impact weight |

### 1.2 `risk_cells` (Materialized Projection)
PostGIS-backed materialized view of the spatial field. Used for cold-path recovery and historical analysis.
- **Update Trigger**: Refreshed by the Projection Worker after event bus signal.

---

## ⚡ 2. Hot-Path Substrate (Redis Spatial Cache)

To achieve $O(\text{route\_cells})$ latency, the evaluation engine operates on a **Redis-backed H3 Grid**.

- **Key Format**: `udie:risk:res9:<h3_index>`
- **Value**: `float` (Current decayed risk score)
- **TTL**: Managed by the Invalidation Worker based on temporal decay constants ($\tau$).

---

## 🏛️ 3. Historical & Analytical Schema

### 3.1 `risk_snapshots`
Periodic snapshots of the entire global grid for time-travel analysis and model validation.
- **Storage**: Compressed Parquet if exported to S3/Cold storage; `JSONB/Binary` in Postgres.

---

## 📍 4. Indexing & Optimization Strategy

| Index Name | Target | Type | Purpose |
| :--- | :--- | :--- | :--- |
| `idx_events_spatial` | `events_log(coordinate)` | `GIST` | Bounding box queries |
| `idx_events_h3` | `events_log(h3_index)` | `BTREE` | Fast aggregation |
| `idx_events_temporal` | `events_log(observed_at)` | `BRIN` | Time-series range scans |

---

## 🔄 5. Data Flow Invariant
$$Event \rightarrow Ingestion \rightarrow Event Bus \rightarrow \begin{cases} Persistence (Postgres) \\ Materialization (Redis Cache) \end{cases}$$

**Rule**: Any query directly scanning `events_log` in the request path is an architectural violation.

---

MIT © 2026 **UDIE Engineering Group**. 
"Schema is the foundation of deterministic intelligence."
