# UDIE — Urban Disruption Intelligence Engine

UDIE is a spatial intelligence system that models urban disruption as a continuously updated risk field.
It ingests noisy real-world signals, reconciles them through lifecycle rules, and exposes a bounded-cost API for evaluating route exposure.

This is not a navigation engine.
It is a geospatial computation layer designed to remain deterministic, rebuildable, and scalable.

➡ Start with the documentation index: **`docs/INDEX.md`**

---

## What Problem UDIE Solves

Conventional navigation optimizes ETA but ignores infrastructure instability.
UDIE introduces a structured **risk layer** that quantifies environmental disruption such as:

* accidents,
* flooding or water logging,
* construction,
* road blocks,
* civic disturbances.

The system converts these transient signals into a stable spatial model usable by mobile clients or logistics systems.

---

## System Model (Weather-Style Computation)

UDIE behaves like a weather simulation.
It continuously recomputes a spatial field instead of answering queries directly from raw data.

```
          External Signals
     (reports, feeds, sensors)
                  │
                  ▼
            Append-Only Log
              events_log
                  │
                  ▼
        Deduplication + Reinforcement
                  │
                  ▼
           Lifecycle Projection
            events_active
          (decay / expiry)
                  │
                  ▼
        Spatial Materialization (H3)
               risk_cells
                  │
                  ▼
            Bounded Read API
           /events   /risk
```

**Key invariant:** Query cost depends only on the evaluated route, never on total historical data.

---

## Core Characteristics

* Append-only ingestion ensures full replayability.
* Lifecycle decay removes stale signals automatically.
* Spatial aggregation precomputes risk into H3 cells.
* `/risk` queries operate in `O(route_cells)` time.
* Derived tables are disposable. The log is the source of truth.

---

## Technology Stack (Purpose-Driven)

| Layer            | Technology              | Role                                          |
| ---------------- | ----------------------- | --------------------------------------------- |
| Client           | SwiftUI + MapKit        | Visualization and route geometry only         |
| API              | NestJS (TypeScript)     | Orchestration, validation, lifecycle triggers |
| Database         | PostgreSQL 16 + PostGIS | Authoritative computation engine              |
| Spatial Indexing | H3-PG                   | Deterministic spatial bucketing               |
| Infra            | Docker Compose          | Reproducible environment                      |
| Cache            | Redis (optional)        | Non-authoritative read acceleration           |

---

## Run Locally

### 1. Clone Repository

```bash
git clone git@github.com:fallofpheonix/UDIE.git
cd UDIE
```

### 2. Start Backend + Database

```bash
cd backend
cp .env.example .env
docker compose up --build
```

### 3. Verify System Health

```bash
curl http://localhost:3000/api/health
```

Expected response:

```json
{"status":"ok","db":"up"}
```

### 4. Run iOS Client

Open:

```
UDIE.xcodeproj
```

Set API base URL:

* Simulator → `http://127.0.0.1:3000`
* Device → `http://<your-mac-ip>:3000`

---

## Where To Read Next

Read documentation in this order:

1. `docs/ARCHITECTURE.md`
2. `docs/RISK_MODEL.md`
3. `docs/SYSTEM_REQUIREMENTS.md`
4. `docs/VERIFICATION_VALIDATION.md`

This explains the system before inspecting code.

---

## Development Status

* Append-only ingestion pipeline implemented.
* Lifecycle decay and expiry operational.
* H3-based spatial aggregation enabled.
* Materialized `risk_cells` powering bounded queries.
* iOS client visualizes real-time evaluated risk.

Verification and scaling validation are ongoing.

---

## Contribution

Contributions should target:

* ingestion adapters,
* validation tooling,
* spatial model improvements,
* reliability and observability.

Before submitting changes, ensure they do not violate bounded-query guarantees.

---

## License

Add an explicit license file (MIT recommended) before distribution.

---

**Design Rule:**
If a change increases data touched per request, it is incorrect.
