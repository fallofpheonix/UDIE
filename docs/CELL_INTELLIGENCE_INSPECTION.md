# UDIE Cell Intelligence Inspection

## 1) Cell Insight API Design

### Endpoint
`GET /api/cell-insight`

### Query Params
- `h3Index` (required, res9)
- `timeWindowHours` (optional, default `24`, max `168`)
- `includeNeighbors` (optional, default `false`)

### Response (bounded, explainable)
```json
{
  "cell": "8965a2cffffffff",
  "region": "865a2c7ffffffff",
  "asOf": "2026-03-07T14:05:00Z",
  "risk": {
    "weight": 7.42,
    "band": "HIGH",
    "updatedAt": "2026-03-07T14:04:31Z",
    "contributors": {
      "nearbyActiveCells": 4,
      "densityFactor": 1.48
    }
  },
  "reliability": {
    "score": 0.78,
    "incidentCount30d": 12,
    "avgSeverity": 2.4,
    "updatedAt": "2026-03-07T14:00:00Z"
  },
  "forecast": {
    "riskDelta15m": 0.32,
    "riskDelta60m": 0.81,
    "confidence": 0.71,
    "updatedAt": "2026-03-07T14:00:00Z"
  },
  "history": {
    "windowHours": 24,
    "events": 6,
    "topTypes": [
      {"type": "ACCIDENT", "count": 3},
      {"type": "HEAVY_TRAFFIC", "count": 2}
    ],
    "lastObservedAt": "2026-03-07T13:52:14Z"
  },
  "insights": [
    {"type": "HOTSPOT", "severity": "HIGH", "description": "Repeated accident cluster"},
    {"type": "RECURRING_EVENT", "severity": "MEDIUM", "description": "Recurring congestion"}
  ]
}
```

### Contract Notes
- Request path reads only pre-aggregated/read-model tables.
- No raw geometry scans and no route-time recomputation.
- Complexity target: `O(1)` by cell key + bounded window lookups.

---

## 2) Query Optimization Strategy

### Data Sources
- `risk_cells` (current risk surface)
- `reliability_cells` (long-term reliability)
- `forecast_cells` (forecast surface)
- `intelligence_events` (detected patterns)
- `regional_geo_events_v` (history summary only; bounded by `h3_index` + time window)

### Execution Plan (single-cell bounded)
1. Validate `h3Index` format and resolution.
2. Derive `region = h3_to_parent(h3Index, 6)`.
3. Fetch in parallel:
   - risk row by PK (`risk_cells.h3_index`)
   - reliability row by PK (`reliability_cells.h3_index`)
   - latest forecast by PK/time (`forecast_cells.h3_index`)
   - recent intelligence by (`intelligence_events.h3_index`, `created_at desc`, `limit 10`)
   - history aggregate by (`regional_geo_events_v.h3_index`, `observed_at >= now()-window`)
4. Assemble one explainable DTO in service layer.

### Required Indexes
- `risk_cells(h3_index)` PK
- `reliability_cells(h3_index)` PK
- `forecast_cells(h3_index, generated_at DESC)`
- `intelligence_events(h3_index, created_at DESC)`
- `regional_geo_events_v(h3_index, observed_at DESC)`

### Boundedness Controls
- `timeWindowHours <= 168`
- `insights limit <= 10`
- `topTypes limit <= 5`
- Optional neighbor mode restricted to `k=1` only

### Invariant Compliance
- No mutation in endpoint path.
- No scan of `events_log` in request path.
- H3 key-based lookups only.
- Deterministic output for same snapshot state.

---

## 3) UI Interaction Model (iOS)

### Entry Points
- Map marker tap
- Risk card "Inspect Cell"
- Long-press map cell

### Interaction Flow
1. UI resolves tapped location to H3 cell.
2. Calls `GET /api/cell-insight?h3Index=...&timeWindowHours=24`.
3. Opens bottom sheet with 4 sections:
   - **Risk Now** (band, weight, contributors)
   - **Reliability** (score + 30d trend)
   - **Forecast** (15m/60m deltas)
   - **Recent History** (count + top event types)
4. Optional expandable "Why" section from `insights[]`.

### UI Constraints
- Presentation-only; no local scoring.
- Cached last successful response per cell for offline fallback.
- Loading skeleton max 300ms before spinner.
- Error state preserves previous snapshot card.

---

## 4) Rollout Plan
- Phase 1: backend read-only endpoint + indexes.
- Phase 2: iOS bottom-sheet integration.
- Phase 3: neighbor mode (`k=1`) behind feature flag.
