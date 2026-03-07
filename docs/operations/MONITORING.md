# 📊 UDIE Monitoring & Observability Spec (v2.0)

This document defines the metrics, traces, and logging invariants required for real-time urban governance.

---

## 🛰️ 1. Core Service Metrics

UDIE exposes metrics via Prometheus formatting at `/metrics`.

### 1.1 Spatial Performance
- `udie_risk_evaluation_latency_ms`: P95/P99 latency for route evaluation queries (Goal: < 5ms).
- `udie_cache_hit_ratio`: Ratio of Redis Spatial Cache hits to total queries.
- `udie_h3_grid_density`: Total active Res 9 cells in the hot-path grid.

### 1.2 Ingestion & Pulse
- `udie_ingestion_throughput`: Events processed per second per region.
- `udie_materialization_lag_s`: Time delay between event observation and grid materialization.
- `udie_event_bus_backlog`: Number of unprocessed signals in NATS/Kafka.

---

## 🔍 2. Distributed Tracing

UDIE uses OpenTelemetry (OTel) to trace signals across the lifecycle:
`Signal Source -> Ingestion Worker -> Event Bus -> Projection Worker -> Redis Spatial Cache`

**Trace Identifier**: `X-Trace-Id` (Required on every internal request).

---

## 📜 3. Logging Strategy

Logs follow the **Structured JSON** format for automated agent parsing.

| Level | Usage | Requirement |
| :--- | :--- | :--- |
| `FATAL` | Architecture invariant violation. | Must trigger immediate pager alert. |
| `ERROR` | External service failure (DB, Redis, Bus). | Include trace ID and stack trace. |
| `INFO` | Materialization pulse completions. | Include cell update counts and latency. |
| `DEBUG` | Kernel parameter evaluation. | Verbose kernel weight calculations. |

---

## 🖥️ 4. Dashboards (Grafana)

1. **Urban Pulse**: Real-time visualization of ingestion rates and spatial hotspots.
2. **Substrate Health**: Container status, memory usage (important for in-memory grids), and DB connection pool health.
3. **Architecture Audit**: Visualization of latency vs. route complexity to ensure $O(\text{route\_cells})$ remains valid.

---

MIT © 2026 **UDIE Engineering Group**. 
"Observation is the first step toward urban stability."
