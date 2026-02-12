# UDIE — Urban Disruption Intelligence Engine

UDIE is a geospatial risk platform with an iOS client and a backend powered by NestJS + PostgreSQL/PostGIS.

The system visualizes disruption events on a map and computes route risk server-side using spatial distance decay.

## What This Repository Contains

- `UDIE/`: iOS app (SwiftUI + MapKit)
- `backend/`: NestJS API + PostGIS migrations + Docker setup
- `UDIE.xcodeproj`: Xcode project for iOS app

## Architecture

- **Frontend (iOS)**
  - Renders map, filters, routes, and risk card
  - Fetches events from backend (`/api/events`)
  - Fetches route risk from backend (`/api/risk`)
- **Backend (NestJS)**
  - Serves region-based event queries
  - Computes route risk with PostGIS
  - Stores events in PostgreSQL with `GEOGRAPHY(POINT, 4326)`
- **Database (PostgreSQL + PostGIS)**
  - Spatial indexing (GiST)
  - Migration-driven schema

## Key Features

- Bounding-box event query API
- Server-side route-risk scoring (`LOW` / `MEDIUM` / `HIGH`)
- PostGIS distance-decay weighting:
  - `severity * confidence * exp(-distance/200)`
- Dockerized local stack (backend + postgres/postgis + redis)

## Quick Start

### Prerequisites

- macOS (Apple Silicon or Intel)
- Xcode (for iOS)
- Docker Desktop
- `curl`

### 1) Start Backend Stack

```bash
cd /Users/fallofpheonix/ios_swift/UDIE/backend
cp .env.example .env
docker compose up --build
```

### 2) Verify Backend Health

```bash
curl http://localhost:3000/api/health
```

Expected:

```json
{"status":"ok","db":"up"}
```

### 3) (Optional) Seed Test Events

```bash
docker compose exec postgres psql -U udie -d udie -c "
INSERT INTO geo_events (
  city_code, event_type, severity, confidence, source, start_time, geom
) VALUES
  ('BLR', 'ACCIDENT', 5, 0.9, 'ADMIN', now(), ST_SetSRID(ST_MakePoint(77.5948, 12.9718), 4326)::geography),
  ('BLR', 'CONSTRUCTION', 3, 0.7, 'ADMIN', now(), ST_SetSRID(ST_MakePoint(77.5950, 12.9720), 4326)::geography),
  ('BLR', 'HEAVY_TRAFFIC', 4, 0.8, 'ADMIN', now(), ST_SetSRID(ST_MakePoint(77.5945, 12.9715), 4326)::geography);
"
```

### 4) Test Risk Endpoint

```bash
curl -X POST http://localhost:3000/api/risk \
  -H "Content-Type: application/json" \
  -d '{"city":"BLR","coordinates":[{"lat":12.9716,"lng":77.5946},{"lat":12.9721,"lng":77.5951}]}'
```

Expected shape:

```json
{"score":0.123,"level":"LOW","eventCount":2}
```

### 5) Open iOS App

- Open `/Users/fallofpheonix/ios_swift/UDIE/UDIE.xcodeproj` in Xcode
- Build and run `UDIE` scheme

If running on a physical device, ensure backend base URL points to your Mac LAN IP (not `127.0.0.1`).

## API Contracts

### `GET /api/health`

Health check for API and DB connectivity.

### `GET /api/events`

Query params:

- `minLat` (number, required)
- `maxLat` (number, required)
- `minLng` (number, required)
- `maxLng` (number, required)
- `eventTypes` (csv string, optional)
- `minSeverity` (number 1-5, optional)

Example:

```bash
curl "http://localhost:3000/api/events?minLat=12.96&maxLat=12.99&minLng=77.58&maxLng=77.61"
```

### `POST /api/risk` (alias also available: `/api/route-risk`)

Request:

```json
{
  "city": "BLR",
  "coordinates": [
    {"lat": 12.9716, "lng": 77.5946},
    {"lat": 12.9750, "lng": 77.6000}
  ]
}
```

Response:

```json
{
  "score": 0.48,
  "level": "MEDIUM",
  "eventCount": 3
}
```

## Migrations

Located in `backend/migrations/`:

- `001_init.sql`: extensions, enums, core tables
- `002_indexes_and_views.sql`: indexes + active events view
- `006_real_route_risk.sql`: PostGIS risk function

Apply latest migration manually if needed:

```bash
docker compose exec postgres psql -U udie -d udie -f /docker-entrypoint-initdb.d/006_real_route_risk.sql
```

## Troubleshooting

### `Cannot POST /api/risk`

Backend image is stale. Rebuild:

```bash
cd /Users/fallofpheonix/ios_swift/UDIE/backend
docker compose build --no-cache backend
docker compose up -d
```

### `/api/events` returns validation errors for numeric params

Ensure backend is rebuilt with latest DTO parsing changes.

### Docker warning: `version is obsolete`

Safe warning from Compose v2. It does not block execution.

### GitHub SSH message: `successfully authenticated, but GitHub does not provide shell access`

This is expected. SSH auth is working for git operations.

## Security Notes

- Do not commit real secrets.
- Keep `.env` local; commit only `.env.example`.
- Validate that private keys and tokens are not tracked before pushing.

## Current Project Status

- Infrastructure: running
- Risk engine: server-side and active
- iOS integration: backend-driven risk wired
- Ingestion pipeline: scaffolded, not fully implemented yet

## License

Add your preferred license file (`MIT`, `Apache-2.0`, etc.) before public release.
