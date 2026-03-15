from __future__ import annotations

from math import cos, radians
from typing import Annotated

from fastapi import APIRouter, FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware

from app.models import (
    AreaNewsItem,
    BoundingBox,
    DisruptionEvent,
    HealthResponse,
    RiskResponse,
    RouteRiskRequest,
    RouteNavigationRequest,
    RouteNavigationResponse,
    TrafficForecastRequest,
    TrafficForecastResponse,
    TrafficReasonItem,
    TrafficReasonResponse,
)
from app.services import registry, risk_for_route, traffic_forecast_for_point
from app.storage import store

app = FastAPI(title="UDIE Open Data Backend", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
async def health(request: Request) -> HealthResponse:
    namespace = "/api/v1" if request.url.path.startswith("/api/v1") else "/api"
    return HealthResponse(
        status="ok",
        namespace=namespace,
        checked_at=_now_iso(),
        source_count=len(registry.sources),
    )


@router.get("/health/live")
async def health_live() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/health/ready")
async def health_ready(request: Request) -> dict[str, object]:
    namespace = "/api/v1" if request.url.path.startswith("/api/v1") else "/api"
    readiness = store.readiness()
    return {"status": "ok" if readiness.get("db") == "ok" else "degraded", "namespace": namespace, **readiness}


@router.get("/sources")
async def sources(
    city: Annotated[str, Query(min_length=1, max_length=120)],
    lat: Annotated[float | None, Query(ge=-90.0, le=90.0)] = None,
    lng: Annotated[float | None, Query(ge=-180.0, le=180.0)] = None,
    radius_km: Annotated[float, Query(alias="radiusKm", ge=1.0, le=20.0)] = 10.0,
):
    area = _resolve_area(city=city, lat=lat, lng=lng, radius_km=radius_km)
    _, _, statuses = await registry.collect(area)
    return {"area": area.model_dump(by_alias=True), "sources": statuses}


@router.get("/events", response_model=list[DisruptionEvent])
async def events(
    city: Annotated[str, Query(min_length=1, max_length=120)],
    min_lat: Annotated[float | None, Query(alias="minLat", ge=-90.0, le=90.0)] = None,
    max_lat: Annotated[float | None, Query(alias="maxLat", ge=-90.0, le=90.0)] = None,
    min_lng: Annotated[float | None, Query(alias="minLng", ge=-180.0, le=180.0)] = None,
    max_lng: Annotated[float | None, Query(alias="maxLng", ge=-180.0, le=180.0)] = None,
    lat: Annotated[float | None, Query(ge=-90.0, le=90.0)] = None,
    lng: Annotated[float | None, Query(ge=-180.0, le=180.0)] = None,
    radius_km: Annotated[float, Query(alias="radiusKm", ge=1.0, le=20.0)] = 10.0,
    categories: Annotated[str | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 300,
):
    area = _resolve_area(
        city=city,
        min_lat=min_lat,
        max_lat=max_lat,
        min_lng=min_lng,
        max_lng=max_lng,
        lat=lat,
        lng=lng,
        radius_km=radius_km,
    )
    events_data, _, _ = await registry.collect(area)
    if categories:
        requested = {c.strip().lower() for c in categories.split(",") if c.strip()}
        events_data = [item for item in events_data if item.category.lower() in requested]
    return events_data[:limit]


@router.get("/news", response_model=list[AreaNewsItem])
async def news(
    city: Annotated[str, Query(min_length=1, max_length=120)],
    lat: Annotated[float, Query(ge=-90.0, le=90.0)],
    lng: Annotated[float, Query(ge=-180.0, le=180.0)],
    radius_km: Annotated[float, Query(alias="radiusKm", ge=1.0, le=20.0)] = 10.0,
    categories: Annotated[str | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 300,
):
    area = _resolve_area(city=city, lat=lat, lng=lng, radius_km=radius_km)
    _, news_data, _ = await registry.collect(area)

    if categories:
        requested = {c.strip().lower() for c in categories.split(",") if c.strip()}
        news_data = [item for item in news_data if item.category.lower() in requested]

    return news_data[:limit]


@router.get("/traffic-reasons", response_model=TrafficReasonResponse)
async def traffic_reasons(
    city: Annotated[str, Query(min_length=1, max_length=120)],
    lat: Annotated[float, Query(ge=-90.0, le=90.0)],
    lng: Annotated[float, Query(ge=-180.0, le=180.0)],
    radius_km: Annotated[float, Query(alias="radiusKm", ge=1.0, le=20.0)] = 10.0,
    limit: Annotated[int, Query(ge=1, le=10)] = 5,
):
    area = _resolve_area(city=city, lat=lat, lng=lng, radius_km=radius_km)
    events_data, _, _ = await registry.collect(area)
    reasons = _traffic_reason_summary(events_data, limit=limit)
    return TrafficReasonResponse(city=city, radiusKm=radius_km, totalEvents=len(events_data), reasons=reasons)


@router.post("/risk", response_model=RiskResponse)
async def risk(body: RouteRiskRequest):
    return risk_for_route(body.coordinates)


@router.get("/city-dashboard")
async def city_dashboard(
    city: Annotated[str, Query(min_length=1, max_length=120)],
    lat: Annotated[float, Query(ge=-90.0, le=90.0)],
    lng: Annotated[float, Query(ge=-180.0, le=180.0)],
    radius_km: Annotated[float, Query(alias="radiusKm", ge=1.0, le=20.0)] = 10.0,
):
    area = _resolve_area(city=city, lat=lat, lng=lng, radius_km=radius_km)
    events_data, news_data, statuses = await registry.collect(area)

    by_category: dict[str, int] = {}
    for event in events_data:
        by_category[event.category] = by_category.get(event.category, 0) + 1

    return {
        "city": city,
        "radiusKm": radius_km,
        "events": len(events_data),
        "news": len(news_data),
        "riskCells": store.count_risk_cells(),
        "byCategory": by_category,
        "activeSources": [s.name for s in statuses if s.last_error is None],
    }


@router.get("/cell-insight/{cell_id}")
async def cell_insight(cell_id: str):
    insight = store.get_cell_insight(cell_id)
    if insight is None:
        raise HTTPException(status_code=404, detail="Cell not found")
    return insight


@router.post("/admin/rebuild")
async def admin_rebuild():
    result = store.rebuild_from_log()
    return {"status": "ok", **result}


@router.post("/traffic/forecast", response_model=TrafficForecastResponse)
async def traffic_forecast(body: TrafficForecastRequest):
    """Short-term traffic forecast for a geographic point (Prompt 18)."""
    return traffic_forecast_for_point(body.lat, body.lng, body.horizon_minutes)


@router.post("/route", response_model=RouteNavigationResponse)
async def compute_route(body: RouteNavigationRequest):
    """
    Compute a route between two points.
    Returns polyline, navigation steps, ETA and risk score (Prompt 30).
    """
    from app.services import compute_navigation_route
    return compute_navigation_route(body.origin, body.destination, body.mode)


app.include_router(router, prefix="/api", tags=["api"])
app.include_router(router, prefix="/api/v1", tags=["api-v1"])


@app.get("/health")
async def root_health() -> dict[str, str]:
    return {"status": "ok", "message": "UDIE backend online"}


def _resolve_area(
    city: str,
    min_lat: float | None = None,
    max_lat: float | None = None,
    min_lng: float | None = None,
    max_lng: float | None = None,
    lat: float | None = None,
    lng: float | None = None,
    radius_km: float = 10.0,
) -> BoundingBox:
    _ensure_city_supported(city)

    if lat is not None and lng is not None:
        _ensure_india_geo(lat, lng)
        d_lat = radius_km / 111.0
        d_lng = radius_km / max(1.0, 111.0 * cos(radians(lat)))
        return BoundingBox(
            minLat=max(-90.0, lat - d_lat),
            maxLat=min(90.0, lat + d_lat),
            minLng=max(-180.0, lng - d_lng),
            maxLng=min(180.0, lng + d_lng),
            city=city,
        )

    if None not in {min_lat, max_lat, min_lng, max_lng}:
        _ensure_india_geo(min_lat, min_lng)
        _ensure_india_geo(max_lat, max_lng)
        return BoundingBox(
            minLat=min_lat,
            maxLat=max_lat,
            minLng=min_lng,
            maxLng=max_lng,
            city=city,
        )

    raise HTTPException(status_code=422, detail="Provide either lat/lng/radiusKm or minLat/maxLat/minLng/maxLng")


def _now_iso() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).isoformat()


SUPPORTED_INDIAN_CITIES = {
    "new delhi",
    "delhi",
    "mumbai",
    "bengaluru",
    "bangalore",
    "chennai",
    "hyderabad",
    "kolkata",
    "pune",
    "ahmedabad",
    "jaipur",
    "lucknow",
    "bhopal",
    "patna",
    "guwahati",
    "chandigarh",
    "srinagar",
    "kochi",
    "thiruvananthapuram",
    "nagpur",
    "indore",
    "surat",
    "kanpur",
    "varanasi",
    "visakhapatnam",
    "coimbatore",
    "madurai",
}


def _ensure_city_supported(city: str) -> None:
    c = city.strip().lower()
    if c not in SUPPORTED_INDIAN_CITIES:
        raise HTTPException(
            status_code=422,
            detail="Only supported Indian cities are allowed in this deployment",
        )


def _ensure_india_geo(lat: float, lng: float) -> None:
    if not (6.0 <= lat <= 38.5 and 68.0 <= lng <= 98.0):
        raise HTTPException(status_code=422, detail="Coordinates must be within India bounds")


def _traffic_reason_summary(events_data: list[DisruptionEvent], limit: int) -> list[TrafficReasonItem]:
    grouped: dict[str, dict[str, object]] = {}
    for event in events_data:
        category = event.category.lower().strip()
        node = grouped.get(category)
        if node is None:
            node = {"count": 0, "severity_sum": 0.0, "titles": [], "category": category}
            grouped[category] = node
        node["count"] = int(node["count"]) + 1
        node["severity_sum"] = float(node["severity_sum"]) + float(event.severity)
        titles = node["titles"]
        if isinstance(titles, list) and len(titles) < 3 and event.title not in titles:
            titles.append(event.title)

    rows: list[TrafficReasonItem] = []
    for category, node in grouped.items():
        count = int(node["count"])
        if count <= 0:
            continue
        avg_severity = float(node["severity_sum"]) / count
        impact_score = count * avg_severity * _category_weight(category)
        rows.append(
            TrafficReasonItem(
                reason=_reason_label_for_category(category),
                category=category,
                eventCount=count,
                avgSeverity=round(avg_severity, 4),
                impactScore=round(impact_score, 4),
                sampleTitles=[str(x) for x in node["titles"]],
            )
        )

    rows.sort(key=lambda x: (x.impact_score, x.event_count, x.avg_severity), reverse=True)
    return rows[:limit]


def _reason_label_for_category(category: str) -> str:
    labels = {
        "construction": "Construction or road work",
        "accident": "Accident or collision",
        "gangfight_or_violence": "Security or violence incident",
        "vip_movement": "VIP or minister movement",
        "weather_disruption": "Weather disruption",
        "public_safety": "Public safety alert",
    }
    return labels.get(category, "General traffic disruption")


def _category_weight(category: str) -> float:
    weights = {
        "accident": 1.40,
        "vip_movement": 1.35,
        "gangfight_or_violence": 1.35,
        "construction": 1.20,
        "public_safety": 1.10,
        "weather_disruption": 1.10,
    }
    return weights.get(category, 1.00)
