# UDIE Diagnostic Protocol (Corrected)

## Layer 1: Container Runtime
Verify containers exist and are healthy.
```bash
docker ps
docker inspect --format='{{.State.Health.Status}}' udie-postgres
docker inspect --format='{{.State.Health.Status}}' udie-backend
```

## Layer 2: Transport Handshake
Verify the backend is listening and reachable.
```bash
docker logs udie-backend | grep "Nest application successfully started"
docker port udie-backend
curl http://localhost:3000
```

## Layer 3: API Contract Discovery
Detect active API prefix.
```bash
curl -i http://localhost:3000/api/v1/health
curl -i http://localhost:3000/api/health
```

## Layer 4: Database Connectivity
Check backend DB connection errors and startup races.
```bash
docker logs udie-backend | grep -i postgres
docker logs udie-backend | grep ECONNREFUSED
```

## Layer 5: Schema Integrity
Verify tables exist and migrations are current.
```bash
docker exec udie-postgres psql -U udie -d udie -c "\dt"
# Verify migration history
docker exec udie-postgres psql -U udie -d udie -c "SELECT * FROM migration_versions ORDER BY applied_at DESC;"
```

## Layer 6: Worker Systems
Verify background job loops.
```bash
docker logs udie-backend | grep MATERIALIZE
docker logs udie-backend | grep PROJECTION
docker logs udie-backend | grep LIFECYCLE
```

## Layer 7: Spatial Integrity
Check spatial pipeline and H3 configuration.
```sql
SELECT count(*) FROM risk_cells;
SELECT count(*) FROM regional_geo_events_v;
-- Verify PostGIS and H3 resolution
SELECT PostGIS_version();
SELECT h3_get_resolution(h3_index) FROM risk_cells LIMIT 1;
```

## Layer 8: Mutation Permissions
If risk grid updates fail, check for session-scoped permission blockers.
```bash
docker logs udie-backend | grep "Direct mutation"
```

## Layer 10: Observability & Metrics (Performance)
If the API is functional but results feel slow or missing:
1. **Worker Lag**: `docker logs udie-backend | grep "worker lag"`
2. **Ingestion Rate**: `docker logs udie-backend | grep "signals processed"`
3. **Cache Hit Ratio**: Check Redis logs or UDIE telemetry for "cache hit/miss".
4. **API Latency**: Use `time curl ...` to measure response times.

---

## 🛠 Mandatory Reproducibility
Every diagnosis must be backed by a minimal reproducible command. Use these templates:

### A. API Reachability
```bash
curl -i -X GET "http://localhost:3000/api/v1/health"
```

### B. Functional Event Query
```bash
curl -i -X GET "http://localhost:3000/api/v1/events?minLat=28.5&maxLat=28.7&minLng=77.1&maxLng=77.3"
```

### C. Database Table Verification
```bash
docker exec udie-postgres psql -U udie -d udie -c "\dt"
```

### D. Schema Column Check
```bash
docker exec udie-postgres psql -U udie -d udie -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'geo_events';"
```
