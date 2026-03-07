# 📡 UDIE API Specification (v2.0)

This document defines the public HTTP API for the UDIE spatial intelligence engine. The API exposures disruption intelligence and route evaluation while enforcing architectural invariants that guarantee $O(\text{route\_cells})$ query complexity.

---

## 🌐 Connectivity & Transport
- **Base URL**: `http://localhost:3000/api/v1`
- **Inbound Protocol**: HTTPS/REST (Query) + WebSockets (Real-time Stream)
- **Outbound Stream**: Asynchronous event bus (NATS/Kafka)
- **Error Format**: Standardized JSON objects with `errorCode`, `message`, and `traceId`.

---

## ⚖️ Global API Guarantees & Constraints
- **Complexity**: Risk evaluation is $O(\text{route\_cells})$, independent of historical event volume.
- **Route Constraints**: Max 500 vertices / 100 km path length.
- **Spatial Bounding Box**: Max 0.5 deg² area.
- **Cache-First**: All evaluation queries hit the **Redis Spatial Cache** before falling back to PostGIS.

---

## 🏥 1. Health & Lifecycle
### `GET /health/live`
Basic liveness probe for the API container.

### `GET /health/ready`
Readiness probe verifying:
- **Event Bus**: Connection to NATS/Kafka is active.
- **Spatial Cache**: Redis grid is hydrated.
- **Persistence**: PostGIS is reachable and migrations are up-to-date.

---

## 📍 2. Spatial Event Retrieval (Query)
### `GET /events`
Returns disruption signals within a geographic bounding box.
- **Performance Note**: Uses PostGIS-to-H3 aggregation for large areas to prevent in-memory cell bloat.
- **Parameters**: `minLat`, `maxLat`, `minLng`, `maxLng`, `includeArchive` (boolean).

---

## 🛡️ 3. Route Risk Evaluation (Evaluation)
### `POST /risk`
Computes disruption risk for a route polyline.
- **Mechanism**: Douglas-Peucker simplification + Parallel Redis cell lookup.
- **Neighborhood Influence**: Precomputed 3-ring diffusion inclusion.
- **Request**: `{"coordinates": [{"lat": 28.61, "lng": 77.20}, ...]}`
- **Response**: `riskScore` (0.0-1.0), `riskDensity`, `evalLatencyMs`.

---

## 🏛️ 4. City Intelligence Dashboard
### `GET /city-dashboard`
Aggregated urban oversight for a region (e.g., hotspots, trends, reliability index).

### `GET /cell-insight/:h3Index`
Explainable intelligence for a single H3 cell. Returns contributing signals and decay state.

---

## 📊 Risk Classification & Scoring
- **SAFE**: $[0.00, 0.35)$
- **CAUTION**: $[0.35, 0.70)$
- **DANGER**: $[0.70, 1.00)$
- **Formula**: $Risk = 1 - e^{-\lambda \rho}$ (Calibrated against historical incident frequency).

---

MIT © 2026 **UDIE Engineering Group**. 
"Determinstic APIs enable predictable urban navigation."
