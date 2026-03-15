# Backend Architecture

The backend substrate is the authoritative source of intelligence for UDIE, handling spatial compute, event persistence, and prediction.

## 🏗 Subsystems

### 1. Spatial Substrate (NestJS)
- **Location**: `/engine-backend`
- **Domain Modules**:
  - `ingestion`: Signal capture, normalization, and deduplication.
  - `events`: Management of the immutable `events_log`.
  - `risk`: Implementation of spatial kernels and risk aggregation.
  - `spatial`: PostGIS and H3 indexing services.
- **Database**: PostgreSQL with PostGIS, Partitioned by `observed_at` and `region_id`.

### 2. Prediction Engine (Python)
- **Location**: `/udie_backend_py`
- **Role**: Handles heavy-lift spatial utilities, forecasting kernels, and T+X risk projections.
- **Stack**: FastAPI, GeoPandas, H3-Py.

## ⚙️ Operational Flow

1.  **Ingestion**: Raw disruptions enter via REST/WS.
2.  **Persistence**: Events are committed to the immutable `events_log`.
3.  **Projection**: Background workers materialize risk into `risk_cells` and Redis caches.
4.  **Evaluation**: API handlers query the materialized hot-path for sub-millisecond route risk analysis.

## ⚖️ Backend Laws

- **Law of Deterministic Rebuild**: All state must be reproducible from the event log.
- **Law of Hot-Path Isolation**: Evaluation cost must be independent of total event volume.
- **Law of Memory Residency**: Hot-path evaluation data must reside in RAM (Redis).

## 🛠 Observability & Health

- **Heartbeat Service**: Monitors worker lag and materialization freshness.
- **Architecture Audit Service**: Continuously verifies schema integrity and query plan safety.
- **Diagnostics**: Specialized endpoints (`/diagnostics/architecture`) surface data-plane degradations.
