# UDIE Python Backend

FastAPI backend for cross-platform UDIE app.

## Why this stack
- Python + FastAPI: easier debugging and deterministic API contracts.
- Free government data adapters (no paid feeds):
  - NDMA Sachet public alerts API
  - NDMA location-wise alerts API
  - NDMA state dashboard API (state-level pressure signal)
- Free database by default:
  - Local SQLite (`udie_state.db`)
  - No Firebase required
  - No paid cloud database required

## Run
```bash
cd udie_backend_py
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Optional DB path override (still SQLite):
```bash
export UDIE_DB_PATH=./udie_state.db
```

## Key Endpoints
- `GET /api/health`
- `GET /api/v1/health`
- `GET /api/news?city=Delhi&lat=28.6139&lng=77.2090&radiusKm=10`
- `GET /api/events?city=Delhi&lat=28.6139&lng=77.2090&radiusKm=10`
- `GET /api/sources?city=Delhi&lat=28.6139&lng=77.2090&radiusKm=10`
- `POST /api/risk`

## Notes
- Radius query supports 1-20 km.
- Deployment policy is India-only; non-Indian cities and out-of-India coordinates are rejected with `422`.
- Coverage for categories like gangfight/VIP movement is data-source dependent.
- Persistent storage is SQLite only in this deployment profile (free tier friendly).
