# ⚙️ UDIE Configuration Reference

This document describes all configurable parameters required to run the UDIE system. Configuration is divided into backend environment, model parameters, frontend clients, and runtime diagnostics.

⸻

## 🖥️ Backend Environment (.env)

The backend service is configured through environment variables.

### Core Backend Variables
| Variable | Description | Default |
| :--- | :--- | :--- |
| `DATABASE_URL` | PostgreSQL/PostGIS connection string | **REQUIRED** |
| `PORT` | API server listening port | `3000` |
| `NODE_ENV` | Runtime environment (`development` \| `production`) | `development` |
| `REDIS_URL` | Optional Redis cache endpoint | `redis://localhost:6379` |

### Spatial Configuration
These parameters control spatial discretization and request limits, enforced by the `SpatialValidationGuard`.

| Variable | Description | Default |
| :--- | :--- | :--- |
| `H3_RESOLUTION` | Spatial aggregation resolution | `9` |
| `MAX_ROUTE_VERTICES` | Maximum vertices allowed per route | `500` |
| `MAX_ROUTE_DISTANCE_KM` | Maximum route length | `100` |
| `MAX_BOUNDING_BOX_DEG2` | Maximum area for spatial queries | `0.5` |

### Risk Grid Configuration
Controls the in-memory evaluation grid hydrated from `risk_cells` by the `RiskGridService`.

| Variable | Description | Default |
| :--- | :--- | :--- |
| `RISK_GRID_REFRESH_SECONDS` | Grid reload interval | `30` |
| `MAX_QUERY_CELLS` | Max cells evaluated per request | `1000` |

### Worker Configuration
| Variable | Description | Default |
| :--- | :--- | :--- |
| `WORKER_MATERIALIZATION_INTERVAL` | Risk cell aggregation frequency | `60s` |
| `WORKER_SNAPSHOT_INTERVAL` | Snapshot generation frequency | `300s` |
| `WORKER_AUDIT_INTERVAL` | Architecture invariant check | `6h` |

### Diagnostics Configuration
| Variable | Description | Default |
| :--- | :--- | :--- |
| `DIAGNOSTICS_ENABLED` | Enable architecture monitoring | `true` |
| `PERFORMANCE_MONITOR_ENABLED` | Enable latency tracking | `true` |
| `SIMULATION_ENABLED` | Enable simulation sandbox APIs | `true` |

⸻

## 🧠 Model Parameters
Mathematical parameters are stored in the `model_parameters` table to allow tuning without redeployment.

| Parameter | Description | Default |
| :--- | :--- | :--- |
| `lambda` | Spatial decay radius | `250 m` |
| `k` | Normalization scale | `20` |
| `gamma` | Temporal decay factor | `0.97` |
| `alpha` | Density amplification factor | `0.4` |

⸻

## 📱 iOS Configuration
iOS clients use configuration values defined in `Info.plist`.
- **UDIE_API_BASE_URL**: Authoritative backend endpoint.

⸻

## 🖥️ Web Admin Configuration
Web dashboard variables (Vite environment):
- **VITE_API_BASE_URL**: Backend endpoint.
- **VITE_MAP_DEFAULT_LAT/LNG**: Initial map center.

⸻

MIT © 2026 **UDIE Engineering**. 
"If you can't measure it, you can't model it."
