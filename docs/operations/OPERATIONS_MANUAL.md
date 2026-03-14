# UDIE: System Operations & Functional Manual

This document provides a comprehensive breakdown of the **Urban Disruption Intelligence Engine (UDIE)**, explaining how it functions, its data architecture, and its current state.

## 1. Project Working: The "Signal to Intelligence" Pipeline

UDIE operates as a deterministic spatial field engine. The pipeline transforms noisy signals into actionable risk data.

### 1.1 Ingestion Flow
1.  **Signal Gateway**: Signals enter via REST (`/api/v1/ingest`).
2.  **Shielding**: `AdversarialProtectionService` blocks spam/attacks; `SignalCredibilityService` weights signals based on source trust.
3.  **H3 Mapping**: Signals are mapped to **H3 Resolution 9** cells (~0.1km²).
4.  **Regional Sharding**: The system identifies the **Resolution 6** "Parent Region" for the signal to route it to the correct database partition.
5.  **Logging**: The raw signal is written to an immutable `regional_events_log`.

### 1.2 Materialization (The "Bake")
1.  **Risk Update**: The engine calculates immediate spatial influence (KDE) for the event and its neighbors (3 rings).
2.  **Grid Update**: It updates the `risk_cells` table using atomic `ON CONFLICT DO UPDATE` increments.
3.  **Projections**: Background workers generate versioned snapshots of the risk field for historical playback.

### 1.3 Evaluation (The "Query")
1.  **Constant Time Lookups**: When a route is sent to the backend, the engine *does not* recalulate risk from scratch. It simply looks up the pre-aggregated values in the `risk_cells` grid.
2.  **Complexity**: This makes evaluation $O(\text{route\_cells})$, meaning the system stays fast even if millions of signals are ingested.

---

## 2. Database Functions: Partitioning & Integrity

UDIE is built for **Nationwide Scaling** using a partitioned PostgreSQL/PostGIS architecture.

### 2.1 Spatial Partitioning
The database is declarative-partitioned by **H3 Resolution 6** (Parent Region).
- **Automation**: The `PartitionManagementService` creates new tables on-the-fly when a signal arrives in a new geographic area.
- **Tables Partitioned**: `regional_events_log`, `geo_events_v`, `risk_grid_v`.

### 2.2 MVCC Bloat Protection
Traditional spatial databases slow down due to constant `UPDATE` calls. UDIE solves this by using **Append-Only Versioning**. Instead of updating a row, the engine inserts a new version of the risk weight and retrieves the latest version during query.

---

## 3. Frontend Implementation: iOS & Web

### 3.1 iOS (SwiftUI)
- **Networking**: `APIClient` features dynamic prefix discovery. If you move from a legacy server (`/api`) to a v1 server (`/api/v1`), the client adapts automatically.
- **Safety**: Includes "Localhost Warnings" to remind developers that physical devices cannot see `localhost`.

### 3.2 Web Admin Hub
- **Architecture**: Vanilla JS with Leaflet and H3-js.
- **Intelligence Radar**: Periodically polls `/intelligence` and `/cell-insight` to show real-time anomalies and AI-detected patterns.

---

## 4. Current Status: Is it Running?

**Status: 🔴 INACTIVE**

- **Backend**: Port 3000 is not responding. Service is likely stopped.
- **Database**: `docker-compose` is currently inactive in the `infra/` directory.
- **Connectivity**: `APIClient` probes are failing with connection timeouts.

### How to Start the System
1.  **Infrastructure**: `cd infra && docker-compose up -d` (Starts Postgres, Redis, Grafana).
2.  **Backend**: `cd engine-backend && npm run start:convert`.
3.  **Frontend**: Open `UDIE.xcodeproj` in Xcode and run on a Simulator.
