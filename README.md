# UDIE — Urban Disruption Intelligence Engine

UDIE converts raw, multi-source urban disruption signals into a stable, materialized spatial risk surface. Rather than treating events as simple map annotations, it accumulates them as weighted energy in an H3 hexagonal grid, subject to spatial diffusion and temporal decay. The result is a backend that answers "what is the current risk on this route?" in under 5ms, regardless of how many raw events exist.

## Architecture

The system is log-derived: the `events_log` table is the only authoritative state. Every other table (`risk_cells`, projections, snapshots) is a deterministic function of that log. This means the entire risk surface can be rebuilt from scratch by replaying events—useful for schema migrations, disaster recovery, and test reproducibility.

**Components:**

| Directory | Role |
|---|---|
| `engine-backend/` | NestJS API. Ingestion, spatial compute, routing, simulation. |
| `udie_backend_py/` | FastAPI service. Aggregates open government data (NDMA). |
| `UDIE/` | Native iOS app (SwiftUI). Real-time disruption map. |
| `udie_mobile/` | Flutter app (cross-platform). Radius-based risk view. |
| `dashboard-admin/` | Static web dashboard. City ops and system health. |
| `infra/` | Docker Compose, Kubernetes, Prometheus/Grafana. |

**Key design decisions:**

- **No ORM.** Direct `pg` queries against a known schema. Avoids the impedance mismatch when working with PostGIS and H3 types.
- **Role-based nodes.** A single binary supports `INGESTION`, `MATERIALIZATION`, or `EVALUATION` roles via `NODE_ROLE` env var. Scales each concern independently.
- **Precomputed risk surface.** Route evaluation reads from Redis-cached `risk_cells`, not the event log. Evaluation cost is O(route cells), not O(events).
- **H3 resolution 9.** ~174m² cells—fine enough for intersection-level accuracy, coarse enough for efficient neighbor operations.

## Setup

**Prerequisites:** Docker, Node.js 18+, Python 3.10+

### Backend (NestJS)

```bash
cd engine-backend
npm install
cp .env.example .env        # edit DATABASE_URL, REDIS_URL as needed
npm run db:migrate
npm run dev
```

### Python spatial service

```bash
cd udie_backend_py
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Full stack (Docker)

```bash
cd infra
docker compose up --build
```

This brings up Postgres (with PostGIS), Redis, both backend services, Prometheus, and Grafana.

### Mobile

```bash
# iOS
open UDIE/UDIE.xcodeproj     # build and run in Xcode

# Flutter
cd udie_mobile && flutter pub get && flutter run
```

> **Physical device note:** iOS simulators can reach `localhost`. Physical devices cannot. Set `UDIE_BACKEND_URL` in your Xcode scheme to your host's LAN IP (e.g. `http://192.168.1.x:3000`).

## Key endpoints

See [API_REFERENCE.md](./API_REFERENCE.md) for the full contract.

```
GET  /api/v1/health/ready     — readiness (DB + risk surface freshness)
GET  /api/v1/events           — events within a bounding box
POST /api/v1/risk             — route risk score for a coordinate polyline
GET  /api/v1/city-dashboard   — aggregated city-level metrics
GET  /api/v1/cell-insight     — per-cell risk history and decay state
```

## Running tests

```bash
cd engine-backend
npm test                      # all tests
npm run test:risk             # risk kernel only
npm run verify:architecture   # enforces no-ORM, append-only log, and other invariants
```

## Rebuilding the risk surface

If `risk_cells` is empty or stale (common after a fresh migration), trigger a replay:

```bash
npm run validate:rebuild
```

The readiness endpoint (`GET /health/ready`) reflects surface freshness and will show `degraded` until materialization completes.

## License

MIT © 2026 UDIE Engineering Group
