# Configuration Reference

UDIE uses environment-based configuration for across all subsystems.

## 🛠 Shared Environment Variables

- `PORT`: API port (default: 3000).
- `DATABASE_URL`: PostgreSQL connection string.
- `REDIS_URL`: Redis Hot-path cache connection string.
- `API_PREFIX`: Dynamic prefix resolution (`/api/v1` recommended).

## 📡 Backend-Specific (`engine-backend/.env`)

| Key | Default | Description |
| :--- | :--- | :--- |
| `DB_HOST` | `localhost` | Postgres host address. |
| `DB_PORT` | `5432` | Postgres port. |
| `DB_NAME` | `udie` | Database name. |
| `H3_RESOLUTION` | `9`| Native spatial indexing resolution. |
| `DISSIPATION_TAU` | `3600` | Temporal decay constant (seconds). |

## 📱 Mobile Configuration

### iOS Simulator vs Physical Device
Physical devices **cannot** connect to `localhost`. You must use your host Mac's LAN IP.
- **Simulator**: `http://localhost:3000/api/v1`
- **Device**: `http://<LAN_IP>:3000/api/v1`

`APIClient.swift` handles dynamic base URL injection and prefix discovery. Ensure `UDIE_BACKEND_URL` is set in your build scheme or config file.

## 🏗 Subsystem Toggles

- `ENABLE_SIMULATION`: Set to `true` to allow ingestion of simulation event streams.
- `ALLOW_DERIVED_MUTATION`: Required for workers to refresh `risk_cells`. Must be `false` for API-only nodes.
