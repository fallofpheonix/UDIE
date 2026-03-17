# API Reference

The UDIE API is an authoritative HTTP contract exposed by the NestJS backend on `/api/v1`.

## Base URL

- **Local Development**: `http://localhost:3000/api/v1`
- **Prefix Discovery**: `APIClient.swift` dynamically probes `/api/v1` and `/api` to handle version drift.

## Health & Readiness

### `GET /health/live`
Confirms the process is running. Returns `200 OK`.

### `GET /health/ready`
Confirms the system is ready to serve queries. Reflects:
- Database reachability.
- Risk-surface freshness (`risk_cells` materialization).
- Worker heartbeat status.

---

## Events

### `GET /events`
Returns disruptions within a bounding box.

**Query Parameters:**
- `minLat`, `maxLat`: Latitude bounds.
- `minLng`, `maxLng`: Longitude bounds.
- `city` (Optional): Filter by city name.
- `includeArchive` (Optional): Include decayed/expired events.

---

## Route Risk

### `POST /risk`
Computes the risk score for a polyline.

**Request Body:**
```json
{
  "coordinates": [
    { "lat": 28.6139, "lng": 77.2090 },
    { "lat": 28.6200, "lng": 77.2300 }
  ],
  "city": "Delhi"
}
```

**Response Fields:**
- `riskScore`: Saturated score in `[0, 1)`.
- `riskLevel`: Categorical rating (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`).
- `explanation`: Human-readable summary of contributing disruptions.

---

## Dashboard & Intelligence

### `GET /city-dashboard`
Aggregated metrics (hotspots, event counts, trend gradients) for city-level visualization.

### `GET /cell-insight`
Cell-level intelligence including historical weight and current decay state.

---

## Constraints

- **Bounded Queries**: Geographic queries are limited to a maximum bounding box size (default 0.5 deg²).
- **Contract-Valid Parameters**: Required query parameters must be provided; empty/default values result in `400 Bad Request`.
- **Deterministic Latency**: Evaluation endpoints target sub-5ms responses via in-memory grid lookups.
