# UDIE Backend

Backend-first implementation for Urban Disruption Intelligence Engine.

## Run locally

1. Copy env:

```bash
cp .env.example .env
```

2. Start infra and backend:

```bash
docker compose up --build
```

3. Health check:

```bash
curl http://localhost:3000/api/health
```

4. Query events:

```bash
curl "http://localhost:3000/api/events?minLat=12.9&maxLat=13.1&minLng=77.5&maxLng=77.7"
```

## Migrations

- `migrations/001_init.sql` creates extensions, enums, and base tables.
- `migrations/002_indexes_and_views.sql` creates indexes and active events view.

## Frozen v1 contracts

- `GET /api/events`
- `POST /api/risk` (alias: `/api/route-risk`)
