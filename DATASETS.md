# Datasets & Data Schema

UDIE operates on an **Event-Sourced Substrate**. There are no static datasets in the conventional sense; the state is a projection of high-volume event logs.

## 🧱 Authoritative Schema (`events_log`)

All system intelligence is derived from the immutable `events_log`:

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | Unique event identifier. |
| `coordinate` | `Geography` | WGS84 Point. |
| `h3_index` | `BIGINT` | H3 resolution 9 cell index. |
| `observed_at` | `Timestamp` | Time of occurrence. |
| `weight` | `Float` | Initial impact weight. |

## ⚡ Materialized Projections

- **`risk_cells`**: Aggregated, decayed risk field indexed by H3.
- **`regional_geo_events_v`**: Spatially partitioned view for viewport-bounded event fetching.
- **`risk_snapshots`**: Periodic captures of the global cell state for historical analysis.

## 🧪 Simulation Data

Simulation data is stored in `simulation_events` to prevent contamination of production metrics. This data is ingested via the `/events` endpoint when the `ENABLE_SIMULATION` flag is active.

## 📍 Data Contracts (STI)

The **Standard Tool Interface (STI)** defines how agents and external sensors submit signals.
- **Ingestion Contract**: Requires `lat`, `lng`, `type`, and `initial_weight`.
- **Validation**: Signals are rejected if they fall outside bounded operational zones (e.g., city limits).
