# Codebase Structure

The UDIE repository is organized to decouple spatial compute, client interfaces, and system contracts.

## 🌲 Technical Hierarchy

- **`engine-backend/`** (NestJS): The core spatial substrate.
  - `src/modules/ingestion`: Signal capture and normalization.
  - `src/modules/risk`: Field weight and kernel evaluation.
  - `src/modules/spatial`: H3 indexing and PostGIS geometry.
  - `src/database`: Schema definitions, migrations, and spatial views.
- **`udie_backend_py/`**: Python-based spatial utilities and prediction kernels.
- **`UDIE/`** (Swift): Native iOS Client featuring map intelligence and sync state management.
- **`udie_mobile/`** (Flutter): Cross-platform mobile client for Android/iOS.
- **`dashboard-admin/`**: Web-based interface for city operations and monitoring.
- **`infra/`**: Global orchestration, Docker configurations, and monitoring (Prometheus/Grafana).
- **`docs/`**: (DEPRECATED - Replaced by canonical root documentation).

## ⚖️ Ownership Rules

1.  **Backend Authority**: All spatial risk logic resides in the backend. Clients must never reimplement risk kernels.
2.  **State Isolation**: UI state (syncing, connectivity) must reside in core state machines, not within views.
3.  **Module Decoupling**: Core modules must not depend on feature-level implementations.
4.  **Contract-First**: A feature is only complete when its API contract and diagnostic endpoints are verified.

## 🚫 Forbidden Patterns

- **Absolute Paths**: Machine-specific paths in scripts or configs are prohibited.
- **Raw SQL Scans**: All requests must query derived surfaces/repos, never the raw event log.
- **Unverified Connectivity**: Clients must distinguish between Transport, Contract, and Data-Plane failures.
