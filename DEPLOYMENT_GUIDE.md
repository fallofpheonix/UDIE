# Deployment Guide

UDIE is designed for containerized deployment with strict isolation between Compute, State, and Client layers.

## 🐳 Infrastructure Orchestration

The system uses Docker Compose for local and staging environments and Kubernetes for production scale.

### Core Containers
- **`udie-backend`**: NestJS API and Worker node.
- **`udie-spatial-py`**: Python spatial/prediction kernel node.
- **`udie-db`**: PostgreSQL 15 + PostGIS 3.
- **`udie-cache`**: Redis 7.

## 🚀 Deployment Steps

### 1. Provision Substrate
Ensure Postgres and Redis are reachable. Run migrations:
```bash
docker exec -it udie-backend npm run db:migrate
```

### 2. Configure Environment
Set `ALLOW_DERIVED_MUTATION=true` for worker nodes and `false` for API-only nodes to prevent write contention. See [CONFIGURATION.md](file:///Users/fallofpheonix/Project/UDIE/CONFIGURATION.md).

### 3. Prime the Grid
Upon first boot, the system may take several minutes to materialize the risk surface from the `events_log`. Monitor readiness via `GET /health/ready`.

## 🏗 Production Topology

- **Replication**: Use Postgres streaming replication for read-only API nodes.
- **Partitioning**: Ensure H3 Res 6 partitions are correctly configured in the `database/views`.
- **Monitoring**: Integration with Prometheus and Grafana is required to track "Worker Lag" and "Grid Freshness".

## 🚑 Troubleshooting

### "Connected • Not synced yet"
- **Cause**: Client can reach the API, but `risk_cells` is empty or the worker is failing.
- **Fix**: Check `REBUILD_STATUS` in the `/diagnostics/architecture` endpoint.

### 404 on Dokcumented Routes
- **Cause**: API Prefix mismatch.
- **Fix**: Verify `API_PREFIX` environment variable matches client expectations.
