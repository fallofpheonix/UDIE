# UDIE System Assumptions (Corrected)

## 🌉 Networking Model

### Docker Bridge (172.x.x.x)
- **Host Mac**: Reachable directly via bridge IP.
- **Physical iPhone**: **NOT** reachable. Must use host port mapping and Mac LAN IP.
- **External Machine**: **NOT** reachable.

### iOS Simulator
Resolves `localhost` and `127.0.0.1` to the Mac host. Valid backend addresses include `localhost`, `127.0.0.1`, and the Mac's LAN IP.

### Physical iPhone
**Must** use the host Mac's LAN IP (e.g., `192.168.1.x`). Never use `172.x.x.x`.

---

## 🗄 Database & Schema Constraints

### Derived Tables
Tables like `risk_cells` and `geo_events` are managed by worker pipelines. Direct mutation is prohibited unless the session-scoped flag is set:
```sql
set_config('udie.allow_derived_mutation', 'true', true);
```
Agents must check worker logs for "Direct mutation prohibited" to diagnose missing flags.

### API Prefix Versioning
The UDIE backend may expose endpoints via `/api/v1` or `/api`. The active prefix **must be discovered dynamically** by probing `/health`.

---

## ⚙️ Worker Dependency Chain
Data flows through a strict pipeline. If any stage fails, the API may return stale or empty results:
1. **Raw Events** (Social/Sensor)
2. **Ingestion Worker** (Parsing & Validation)
3. **Projection Worker** (Coordinate to H3 mapping)
4. **Risk Materialization** (Heat diffusion calculation)
5. **Spatial Grid** (Redis/Postgres `risk_cells`)

---

## 🛠 Application Startup Model
1. **Postgres Boot**: May accept connections before database initialization.
2. **Migrations**: Applied to the `udie` database (Check `migration_versions`).
3. **Backend Service**: Starts only after DB readiness.
4. **Workers**: Independent boot; must handle DB connection retries.

Always use `/api/v1/health/ready` to verify full system operational status.
