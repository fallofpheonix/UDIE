# API Specification

This document provides technical details for the UDIE Backend API.

## Base URL
Default: `http://localhost:3000/api`

## Endpoints

### 1. Health Check
`GET /health`
- **Purpose**: Verify if the server and database are operational.
- **Response**:
  ```json
  {
    "status": "ok",
    "db": "up",
    "riskSurface": {
      "stale": false,
      "freshnessSeconds": 42.13,
      "maxAllowedSeconds": 300
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
  - `city` (string): 3-letter city code (e.g., DEL, BLR).
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
- **Complexity Contract**: Query path intersects route cells against `risk_cells` only.
- **Body**:
  ```json
  {
    "city": "DEL",
    "coordinates": [
      {"lat": 28.6139, "lng": 77.2090},
      {"lat": 28.6150, "lng": 77.2110}
    ]
  }
  ```
- **Response**:
  ```json
  {
    "score": 0.452,
    "level": "MEDIUM",
    "eventCount": 3,
    "modelVersion": 2,
    "latencyMs": 5.2
  }
  ```

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
