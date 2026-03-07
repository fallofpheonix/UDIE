# 🛠️ UDIE Local Setup Guide

This guide explains how to run the Urban Disruption Intelligence Engine (UDIE) locally. The local environment replicates the production architecture: PostgreSQL + PostGIS, append-only event log, materialized risk surface, and in-memory risk grid.

⸻

## 📋 Prerequisites

Required:
- **Node.js** ≥ 18 (LTS recommended)
- **Docker** ≥ 24 & **Docker Compose**

Optional:
- **Xcode** ≥ 15 (For iOS client development)
- **curl** (For API verification)

⸻

## 🚀 Backend Setup

### 1. Navigate & Install
```bash
cd backend
npm install
```

### 2. Configure Environment
```bash
cp .env.example .env
```
*Verify `PORT=3000` and `DATABASE_URL` in `.env`.*

### 3. Start Infrastructure
```bash
docker compose up -d --build
```
*Verify with `docker ps`. Expected container: `udie-postgres`.*

### 4. Run Database Migrations
Initialize the specialized unified schema.
```bash
./scripts/migrate_all.sh
```

### 5. Start Backend Server
```bash
npm run start:dev
```
*API available at: `http://localhost:3000/api/v1`*

⸻

## 🧪 Verification

### Liveness & Readiness
```bash
# Liveness Probe
curl http://localhost:3000/api/v1/health/live

# Readiness Probe (Checks DB, Workers, Risk Grid)
curl http://localhost:3000/api/v1/health/ready
```

### Architecture Diagnostics
Verify system invariants and "Laws of UDIE".
```bash
curl http://localhost:3000/api/v1/diagnostics/architecture
```

### Simulation Test
Run an isolated scenario (writes only to `simulation_events`).
```bash
curl -X POST http://localhost:3000/api/v1/simulation/events \
  -H "Content-Type: application/json" \
  -d '{"type": "FLOOD", "center": [28.61, 77.21], "severity": 4}'
```

⸻

## 📱 iOS Client Setup

1. **Open Project**: `open UDIE.xcodeproj`
2. **Configure API**: Set `UDIE_API_BASE_URL=http://localhost:3000/api/v1` in the run scheme.
3. **Run**: `Cmd + R` on an iPhone 15 simulator.

⸻

## 🛠️ Troubleshooting

- **DB Connection**: Check `docker ps` and `docker logs udie-postgres`.
- **Migrations**: Verify PostGIS via `SELECT PostGIS_Full_Version();`.
- **API Unreachable**: Check port usage with `lsof -i :3000`.

⸻

MIT © 2026 **UDIE Engineering**. 
"If setup isn't deterministic, the system isn't either."
