# 📄 UDIE Event Schema & Spatial Data Model (v1.0)

This document defines the **canonical data structures used throughout the UDIE platform**. 

All services must adhere to these schemas to ensure:
* deterministic data processing
* consistent spatial aggregation
* reliable streaming interfaces
* forward-compatible schema evolution

---

## 1. Core Data Model Principles

The UDIE data model follows four principles:
1. **Event-driven architecture**
2. **Spatial indexing via H3**
3. **Immutable event records**
4. **Schema versioning for evolution**

All events must include: `event_id`, `timestamp`, `location`, `event_type`, `severity`, `confidence`. Events are **append-only records**.

---

## 2. Canonical Event Schema

Each incoming disruption signal is represented as an **Event Object**.

```json
{
  "event_id": "uuid",
  "schema_version": "1.0",
  "timestamp": "ISO8601",
  "source": "string",
  "location": {
    "lat": "float",
    "lon": "float",
    "h3_index": "string"
  },
  "event_type": "string",
  "severity_score": "float",
  "confidence_score": "float",
  "metadata": {}
}
```

### Field Definitions
| Field | Description |
| :--- | :--- |
| `event_id` | Unique event identifier (deterministic hash). |
| `schema_version` | Event schema version for governance. |
| `timestamp` | Event generation time (observed time). |
| `source` | Data source identifier (e.g., "TWITTER_FEED_01"). |
| `location` | Geospatial coordinates and H3 index. |
| `event_type` | Event category (see Taxonomy). |
| `severity_score` | Event impact score (0–1). |
| `confidence_score` | Reliability estimate (Multi-factor Ω). |
| `metadata` | Source-specific payload. |

---

## 3. Event Type Taxonomy

Events must belong to a controlled hierarchy:
* **`fire`**
* **`crime`**
* **`traffic`** (`traffic.congestion`, `traffic.accident`)
* **`weather`** (`weather.storm`, `weather.flood`)
* **`infrastructure`**
* **`health`**
* **`crowd`**
* **`transport`**

---

## 4. H3 Spatial Cell Schema

Spatial aggregation occurs at the **H3 cell level**.

```json
{
  "h3_index": "string",
  "resolution": "int",
  "timestamp": "ISO8601",
  "event_density": "float",
  "risk_score": "float",
  "anomaly_score": "float",
  "confidence_score": "float",
  "agent_activity": "boolean"
}
```

---

## 5. Temporal Aggregation Windows

Each cell maintains multiple rolling windows to support different analytical speeds:
* **1 minute**: Streaming (Anomaly detection & Alerts).
* **5 minutes**: Tactical (Core risk field updates).
* **15 minutes**: Forensic (Trend analysis & Diffusion).
* **1 hour**: Strategic (Historical baselining).

---

## 6. Forecast Schema

Forecast objects describe predicted disruptions.

```json
{
  "forecast_id": "uuid",
  "origin_cell": "h3_index",
  "timestamp": "ISO8601",
  "direction_vector": {
    "bearing": "float",
    "distance_km": "float"
  },
  "spread_probability": "float",
  "time_horizon_minutes": "int",
  "confidence_score": "float"
}
```

---

## 7. Agent Activity Schema

Agent systems (ReAct) generate reasoning traces for audit and debugging.

```json
{
  "agent_id": "string",
  "task_id": "uuid",
  "timestamp": "ISO8601",
  "action_type": "string",
  "input_reference": "string",
  "result_summary": "string"
}
```

---

## 8. Spatial Tile Schema (Wire Protocol)

Tiles sent to the UI contain aggregated spatial data for rendering.
* **Aggregated cell metrics**
* **Active events**
* **Forecast trajectories**

---

## 9. Schema Governance & Versioning

* **Versioning**: SEMVER applied to schemas. `1.1` (Backward compatible), `2.0` (Breaking).
* **Validation**: Incoming events must pass coordinate sanity, timestamp validity, and schema compliance.
* **Error Handling**: Invalid events are routed to a **Dead Letter Queue (DLQ)**.

---

## 10. Data Integrity & Retention

* **Retention**: Raw events (30 days), Metrics (1 year), Training data (Indefinite).
* **Query Model**: Supports H3-based spatial lookups and time-series trend analysis.

---

MIT © 2026 **UDIE Engineering Group**. 
"Data defines the field; the schema defines the truth."
