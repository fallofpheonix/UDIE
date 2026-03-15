from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from math import exp

import httpx

from app.config import settings
from app.models import (
    AreaNewsItem,
    BoundingBox,
    DisruptionEvent,
    NavigationStep,
    RiskResponse,
    RouteNavigationResponse,
    RoutePoint,
    SourceStatus,
    TrafficForecastResponse,
    now_utc,
)
from app.sources.base import GovernmentSource, SourceResult
from app.sources.india import NdmaLocationAlertSource, NdmaSachetAlertSource, NdmaStateDashboardSource
from app.storage import store


@dataclass
class SourceCacheEntry:
    ts: float
    events: list[DisruptionEvent]
    news: list[AreaNewsItem]
    statuses: list[SourceStatus]


class SourceRegistry:
    def __init__(self) -> None:
        self._sources: list[GovernmentSource] = [
            NdmaSachetAlertSource(),
            NdmaLocationAlertSource(),
            NdmaStateDashboardSource(),
        ]
        self._cache: dict[str, SourceCacheEntry] = {}
        self._lock = asyncio.Lock()

    @property
    def sources(self) -> list[GovernmentSource]:
        return self._sources

    async def collect(self, area: BoundingBox) -> tuple[list[DisruptionEvent], list[AreaNewsItem], list[SourceStatus]]:
        key = self._cache_key(area)
        async with self._lock:
            existing = self._cache.get(key)
            if existing and (time.time() - existing.ts) <= settings.source_cache_ttl_s:
                return existing.events, existing.news, existing.statuses

        headers = {"User-Agent": settings.user_agent, "Accept": "application/json"}
        async with httpx.AsyncClient(timeout=settings.request_timeout_s, headers=headers) as client:
            jobs = [self._fetch_with_retry(source, client, area) for source in self._sources]
            results = await asyncio.gather(*jobs)

        fetched_events: list[DisruptionEvent] = []
        statuses: list[SourceStatus] = []
        for source, result in zip(self._sources, results):
            fetched_events.extend(result.events)
            normalized_error = result.error.strip() if isinstance(result.error, str) else result.error
            if normalized_error == "":
                normalized_error = None
            statuses.append(
                SourceStatus(
                    name=source.name,
                    category=source.category,
                    endpoint=source.endpoint,
                    last_success=now_utc() if normalized_error is None else None,
                    last_error=normalized_error,
                    event_count=len(result.events),
                    news_count=len(result.news),
                )
            )

        new_observations = store.append_events_log(fetched_events)
        store.project_lifecycle(new_observations)
        events = store.get_active_events(area, limit=2000)
        news = store.get_area_news(area, limit=2000)

        # Deterministic ordering for stable UX (mixed timezone formats tolerated).
        events.sort(key=lambda x: _dt_ts(x.updated_at), reverse=True)
        news.sort(key=lambda x: _dt_ts(x.published_at), reverse=True)
        events = _dedup(events, key_fn=lambda e: e.id)
        news = _dedup(news, key_fn=lambda n: n.id)

        entry = SourceCacheEntry(ts=time.time(), events=events, news=news, statuses=statuses)
        async with self._lock:
            self._cache[key] = entry

        return events, news, statuses

    async def _fetch_with_retry(
        self,
        source: GovernmentSource,
        client: httpx.AsyncClient,
        area: BoundingBox,
    ) -> SourceResult:
        retries = 2
        backoff_s = 0.20
        last_result = SourceResult(events=[], news=[], error="Unknown source error")
        for attempt in range(retries + 1):
            try:
                result = await source.fetch(client, area)
            except Exception as exc:  # noqa: BLE001
                result = SourceResult(events=[], news=[], error=str(exc))

            normalized_error = result.error.strip() if isinstance(result.error, str) else result.error
            if not normalized_error:
                return result

            last_result = SourceResult(events=result.events, news=result.news, error=str(normalized_error))
            if attempt < retries and _is_retryable_error(str(normalized_error)):
                await asyncio.sleep(backoff_s * (attempt + 1))
                continue
            break

        return last_result

    @staticmethod
    def _cache_key(area: BoundingBox) -> str:
        return (
            f"{round(area.min_lat, 3)}:{round(area.max_lat, 3)}:"
            f"{round(area.min_lng, 3)}:{round(area.max_lng, 3)}:{area.city.lower().strip()}"
        )


registry = SourceRegistry()


def risk_for_route(points: list[RoutePoint]) -> RiskResponse:
    start = time.perf_counter()
    cells_with_risk = store.get_route_cell_values(points)

    if not cells_with_risk:
        return RiskResponse(
            riskScore=0.0,
            classification="SAFE",
            riskDensity=0.0,
            contributingEvents=0,
            evalLatencyMs=max(1, int((time.perf_counter() - start) * 1000)),
            contributingCells=[],
            scoreComponents={"cellCount": 0.0, "meanCellRisk": 0.0},
        )

    total_risk = sum(r for _, r in cells_with_risk)
    density = total_risk / max(1, len(cells_with_risk))
    score = 1.0 - exp(-4.0 * density)
    classification = "SAFE"
    if score >= 0.70:
        classification = "DANGER"
    elif score >= 0.35:
        classification = "CAUTION"

    contributing_cells = [cell.cell_id for cell, risk in cells_with_risk if risk > 0.0]
    elapsed_ms = int((time.perf_counter() - start) * 1000)
    return RiskResponse(
        riskScore=min(1.0, max(0.0, score)),
        classification=classification,
        riskDensity=max(0.0, density),
        contributingEvents=len(contributing_cells),
        evalLatencyMs=max(1, elapsed_ms),
        contributingCells=contributing_cells[:64],
        scoreComponents={
            "cellCount": float(len(cells_with_risk)),
            "meanCellRisk": float(density),
            "rawRiskSum": float(total_risk),
        },
    )


def _dt_ts(value: datetime) -> float:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC).timestamp()
    return value.astimezone(UTC).timestamp()


def _dedup(items: list[object], key_fn):
    out = []
    seen: set[str] = set()
    for item in items:
        key = key_fn(item)
        if key in seen:
            continue
        seen.add(key)
        out.append(item)
    return out


def _is_retryable_error(msg: str) -> bool:
    m = msg.lower()
    retryable_tokens = ["timeout", "temporar", "connection reset", "503", "502", "429", "rate limit"]
    return any(token in m for token in retryable_tokens)


def traffic_forecast_for_point(lat: float, lng: float, horizon_minutes: int = 15) -> TrafficForecastResponse:
    """
    Short-term traffic forecast using exponential smoothing over stored risk cells (Prompt 18).
    Uses the in-memory risk store as a proxy for congestion intensity.
    """
    from math import exp

    risk_cells = store.get_area_risk_cells(lat=lat, lng=lng, radius_km=1.0)
    avg_risk = sum(r for _, r in risk_cells) / max(1, len(risk_cells)) if risk_cells else 0.0

    # Map risk [0,1] -> congestion speed [5, 60] km/h
    base_speed = max(5.0, 60.0 * (1.0 - avg_risk))

    decay_5m = 0.97
    decay_15m = 0.90
    decay_30m = 0.75

    forecast_5m = base_speed * decay_5m
    forecast_15m = base_speed * decay_15m
    forecast_30m = base_speed * decay_30m

    if base_speed >= 50:
        congestion = "FREE"
    elif base_speed >= 30:
        congestion = "MODERATE"
    elif base_speed >= 15:
        congestion = "HEAVY"
    else:
        congestion = "STANDSTILL"

    return TrafficForecastResponse(
        lat=lat,
        lng=lng,
        forecast5m=round(forecast_5m, 2),
        forecast15m=round(forecast_15m, 2),
        forecast30m=round(forecast_30m, 2),
        congestion_level=congestion,
        generatedAt=now_utc(),
    )


def compute_navigation_route(
    origin: RoutePoint,
    destination: RoutePoint,
    mode: str = "balanced",
) -> RouteNavigationResponse:
    """
    Compute a simple navigation route with risk scoring (Prompt 30).
    Uses straight-line polyline with risk-aware ETA.
    """
    from math import atan2, cos, radians, sin, sqrt

    def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        r = 6371.0
        d_lat = radians(lat2 - lat1)
        d_lng = radians(lng2 - lng1)
        a = sin(d_lat / 2.0) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lng / 2.0) ** 2
        return r * 2.0 * atan2(sqrt(a), sqrt(1.0 - a))

    dist_km = haversine_km(origin.lat, origin.lng, destination.lat, destination.lng)

    # Speed by mode
    speed_map = {"fastest": 60.0, "shortest": 40.0, "safest": 35.0, "balanced": 45.0}
    speed_kmh = speed_map.get(mode, 45.0)

    risk_resp = risk_for_route([origin, destination])
    risk_score = risk_resp.risk_score

    # Risk increases effective travel time
    risk_penalty = 1.0 + risk_score * 0.5
    travel_time_s = (dist_km / speed_kmh) * 3600.0 * risk_penalty

    from datetime import timedelta

    arrival = now_utc() + timedelta(seconds=travel_time_s)
    polyline = [[origin.lng, origin.lat], [destination.lng, destination.lat]]

    steps = [
        NavigationStep(
            stepIndex=0,
            instruction="Proceed to destination",
            distanceM=dist_km * 1000,
            durationS=travel_time_s,
        )
    ]

    return RouteNavigationResponse(
        routePolyline=polyline,
        navigationSteps=steps,
        travelTimeS=round(travel_time_s, 1),
        distanceM=round(dist_km * 1000, 1),
        riskScore=round(risk_score, 4),
        estimatedArrivalIso=arrival.isoformat(),
    )
