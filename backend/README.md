# UDIE Backend

Backend implementation for the Urban Disruption Intelligence Engine. A NestJS service orchestrating a PostGIS "Weather Model" for spatial risk.

## Key Features
- **Hardened Ingestion**: Append-only log truth with spatial deduplication.
- **Materialized Read Path**: Risk scoring via `risk_cells` (O(cells) complexity).
- **Lifecycle Engine**: Automated confidence decay and event expiry.
- **API Guards**: Geometric bounding on route complexity.

## Run Locally

1. Install dependencies:
```bash
npm install
```

2. Start infra and backend:
```bash
docker compose up -d --build
```

3. Apply all migrations:
```bash
npm run migration:up
```

4. Verify core contracts:
```bash
npm run test:risk
npm run validate:plan
npm run validate:rebuild
```

## Documentation
For deep implementation details, see the project [Docs Index](../docs/INDEX.md):
- [Architecture](../docs/ARCHITECTURE.md)
- [Risk Model](../docs/RISK_MODEL.md)
- [Guardrails](../docs/GUARDRAILS.md)

## Frozen API Contracts
- `GET /api/events`: Spatially filtered active events.
- `POST /api/risk`: Normalized risk score for route geometries.
- `GET /api/health`: Service + Database status.
