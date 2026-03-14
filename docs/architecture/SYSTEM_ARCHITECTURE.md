# UDIE System Architecture

This is the canonical architecture document for UDIE.
It replaces the older split across architecture, blueprint, production-architecture, and workflow documents.

## System Philosophy

UDIE models urban disruption as a continuously evolving spatial field.
The system is designed around deterministic replay, bounded query cost, and strict separation between source-of-truth data and derived state.

## Core Subsystems

### Ingestion
- Accepts raw disruption signals from upstream sources and simulation layers.
- Normalizes, validates, and appends them to the authoritative event/log substrate.

### Spatial Compute
- Converts events into H3-indexed spatial state.
- Maintains route-risk, dashboard, snapshot, and intelligence serving data.

### Derived-State Workers
- Materialization, lifecycle, projection, snapshot, diffusion, and intelligence workers update derived projections.
- These workers operate under architectural-law constraints and must never mutate derived tables outside authorized paths.

### API Layer
- Exposes `/api/v1` endpoints for health, events, route risk, city dashboard, snapshots, diagnostics, and related features.
- API responses must preserve explicit contract semantics because clients are thin.

### Mobile/Web Clients
- Native iOS, Flutter mobile, and admin interfaces consume backend intelligence.
- Clients render maps, issue bounded queries, and surface precise connectivity/sync state.

## Data Flow

1. Signals enter through ingestion endpoints or data adapters.
2. The append-only event substrate persists authoritative input.
3. Workers derive `regional_geo_events_v`, `risk_cells`, `risk_snapshots`, intelligence views, and in-memory caches.
4. API handlers query bounded derived-state surfaces rather than replaying raw logs at request time.
5. Clients consume these APIs for visualization and operator interaction.

## Event Lifecycle

### Source of Truth
The authoritative event/log layer is immutable.

### Projection
Workers transform authoritative inputs into versioned regional events and risk surfaces.

### Materialization
Spatial diffusion, lifecycle maintenance, and snapshotting keep the field fresh and queryable.

### Consumption
Route evaluation and dashboards operate only on derived state and cached spatial structures.

## Production Topology

### Compute
- NestJS backend processes APIs and orchestrates workers.
- PostgreSQL/PostGIS remains the authoritative persistence and spatial execution layer.

### Runtime
- Docker/local infrastructure is used for development and verification.
- Production scaling separates concerns by node role rather than introducing multiple authoritative databases.

### Observability
- Health, diagnostics, and worker heartbeat state are required for safe operation.
- Surface freshness and rebuildability are architecture-level concerns, not secondary metrics.

## Constraints

- No direct mutation of derived state without explicit guarded execution.
- No client-side reimplementation of backend intelligence logic.
- No assumption that runtime namespace, connectivity path, or schema version matches documentation without verification.

## Related Documents

- `docs/architecture/DATA_MODEL.md`
- `docs/architecture/LAWS.md`
- `docs/architecture/PERFORMANCE.md`
- `docs/backend/DATA_PIPELINE_BACKEND.md`
- `docs/infrastructure/SYSTEM_DEPLOYMENT_ARCHITECTURE.md`
