# API Specification

This document provides technical details for the UDIE Backend API.

## Base URL
Default: `http://localhost:3000/api/v1`

## Endpoints (Implemented)

### 1. Health Checks

#### `GET /health/live`
- **Purpose**: Liveness probe for orchestration.
- **Response**: `{"status": "ok"}`

#### `GET /health/ready`
- **Purpose**: Readiness probe including DB connectivity and worker health.
- **Response**:
  ```json
  {
    "status": "ok",
    "checks": {
      "database": "up",
      "replicaLagSeconds": 0.0,
      "lockWaiters": 0,
      "maxLockWaitSeconds": 0.0,
      "riskSurface": {
        "stale": false,
        "freshnessSeconds": 42.13
      },
      "workers": [
        { "name": "materialization_worker", "lagSeconds": 10.5, "status": "healthy", "heartbeat": true }
      ]
    }
  }
  ```

### 2. Events Query
`GET /events`
- **Purpose**: Fetch geospatial disruptions for a specific map region.
- **Query Parameters**:
  - `minLat` (number): Minimum latitude.
  - `maxLat` (number): Maximum latitude.
  - `minLng` (number): Minimum longitude.
  - `maxLng` (number): Maximum longitude.
  - `regionId` (string): H3 resolution 6 parent ID (optional).
  - `limit` (number): Pagination limit (Default: 100).
  - `offset` (number): Pagination offset.
- **Constraints**: Bounding box area must not exceed 0.5 deg².
- **Response**: Array of `GeoEvent` objects.
  ```json
  [
    {
      "id": "uuid",
      "event_type": "ACCIDENT",
      "severity": 4,
      "confidence": 0.85,
      "latitude": 28.6139,
      "longitude": 77.2090
    }
  ]
  ```

### 3. Route Risk Calculation
`POST /risk`
- **Purpose**: Calculate a disruption score for a specific polyline.
- **Complexity Contract**: `O(route_cells)` evaluation over in-memory risk grid hydrated from `risk_cells`.
- **Constraints**: Max 1000 vertices per route.
- **Body**:
  ```json
  {
    "coordinates": [
      {"lat": 28.6139, "lng": 77.2090},
      {"lat": 28.6150, "lng": 77.2110}
    ]
  }
  ```
- **Response**:
  ```json
  {
    "riskScore": 0.4521,
    "riskDensity": 1.8472,
    "routeLengthKm": 6.44,
    "cellCount": 38,
    "latencyMs": 0.94
  }
  ```

### 4. City Dashboard
`GET /city-dashboard`
- **Purpose**: Aggregated city intelligence surface for dashboard rendering.
- **Query Parameters**:
  - `minLat`, `maxLat`, `minLng`, `maxLng` (required)
  - `hotspotThreshold` (optional, default `8`)
- **Response Sections**:
  - `heatmapSummary`
  - `topHotspots`
  - `recentIncidents`
  - `cityRiskTrend`

### 5. Risk Snapshots
`GET /risk-snapshots`
- **Purpose**: Time-lapse playback data from periodic `risk_cells` snapshots.
- **Query Parameters**:
  - `start_time`, `end_time` (ISO8601)
  - `minLat`, `maxLat`, `minLng`, `maxLng`
  - `limit` (optional, default `10000`, max `50000`)
- **Boundedness**: Uses H3 bbox cell filtering; no request-time raw event scan.

### 6. Cell Insight
`GET /cell-insight`
- **Purpose**: Explainable single-cell intelligence panel payload.
- **Query Parameters**:
  - `lat` (number)
  - `lng` (number)
- **Response**:
  - `riskScore`
  - `dominantEventType`
  - `recentEventCount`
  - `reliabilityScore`
  - `forecastProbability`
  - `updatedAt`

### 7. Route Options
`POST /route-options`
- **Purpose**: Return top 3 route candidates ranked by travel-time + risk utility.
- **Body**:
  ```json
  {
    "origin": {"lat": 28.6139, "lng": 77.2090},
    "destination": {"lat": 28.6328, "lng": 77.2197}
  }
  ```
- **Response**:
  - `options[]` with `geometry`, `travelTimeMin`, `distanceKm`, `riskScore`, `utility`, `rank`
  - `weights` (`time`, `risk`) loaded from `model_parameters`

### 8. Forecast
`GET /forecast?h3_index=<cell>`
- **Purpose**: Return short-horizon forecast for a cell from `forecast_cells`.
- **Response**:
  - `forecast_30m`
  - `forecast_60m`
  - `sourcePoints`
  - `updatedAt`

### 4. Risk Snapshots (Time-Lapse)
`GET /api/risk-snapshots`
- **Purpose**: Fetch historical risk state for a region.
- **Query Parameters**:
  - `start_time` (ISO8601): Start of timeframe.
  - `end_time` (ISO8601): End of timeframe.
  - `lat`, `lng`, `radius_km`: Spatial filter.

### 5. Cell Intelligence (Explainability)
`GET /api/intelligence/cell/:h3Index`
- **Purpose**: Provide multi-surface breakdown for a specific cell.
- **Response**: Risk, Reliability, Forecast, and natural language summary.

### 6. Route Options (Multi-Route Comparison)
`POST /api/route-options`
- **Purpose**: Compare multiple route candidates based on travel time and risk.
- **Body**:
  ```json
  {
    "origin": {"lat": 28.6139, "lng": 77.2090},
    "destination": {"lat": 28.6150, "lng": 77.2110}
  }
  ```
- **Response**:
  ```json
  {
    "options": [
      {
        "rank": 1,
        "routeId": "R1",
        "distanceKm": 4.2,
        "travelTimeMin": 12.5,
        "riskScore": 0.15,
        "utility": 17.2
      }
    ],
    "weights": { "time": 1, "risk": 30 }
  }
  ```

### 7. City Dashboard
`GET /api/city-dashboard`
- **Purpose**: Regional intelligence summary.
- **Query Parameters**: `minLat`, `maxLat`, `minLng`, `maxLng`, `hotspotThreshold`.
- **Response**: Heatmap summary, top clusters, recent incidents, and 24-hour risk trend.

## Data Types

### Event Types (Enum)
- `ACCIDENT`
- `CONSTRUCTION`
- `METRO_WORK`
- `WATER_LOGGING`
- `PROTEST`
- `HEAVY_TRAFFIC`
- `ROAD_BLOCK`

### Risk Levels
- `LOW` (Score < 0.35)
- `MEDIUM` (0.35 - 0.70)
- `HIGH` (Score >= 0.70)
