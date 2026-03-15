from __future__ import annotations

from datetime import datetime, timezone
from math import atan2, cos, radians, sin, sqrt
from typing import Any, Literal

from pydantic import BaseModel, Field, model_validator


class BoundingBox(BaseModel):
    min_lat: float = Field(alias="minLat", ge=-90.0, le=90.0)
    max_lat: float = Field(alias="maxLat", ge=-90.0, le=90.0)
    min_lng: float = Field(alias="minLng", ge=-180.0, le=180.0)
    max_lng: float = Field(alias="maxLng", ge=-180.0, le=180.0)
    city: str = Field(min_length=1, max_length=120)

    @model_validator(mode="after")
    def validate_bounds(self) -> "BoundingBox":
        if self.max_lat <= self.min_lat:
            raise ValueError("maxLat must be greater than minLat")
        if self.max_lng <= self.min_lng:
            raise ValueError("maxLng must be greater than minLng")
        if (self.max_lat - self.min_lat) * (self.max_lng - self.min_lng) > 25:
            raise ValueError("Requested area is too large")
        return self


class RoutePoint(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lng: float = Field(ge=-180.0, le=180.0)


class RouteRiskRequest(BaseModel):
    coordinates: list[RoutePoint] = Field(min_length=2, max_length=500)

    @model_validator(mode="after")
    def validate_distance(self) -> "RouteRiskRequest":
        if _route_length_km(self.coordinates) > 50.0:
            raise ValueError("Route length exceeds 50 km limit")
        return self


class DisruptionEvent(BaseModel):
    id: str
    source: str
    category: str
    title: str
    lat: float
    lng: float
    severity: float = Field(ge=0.0, le=1.0)
    updated_at: datetime
    city: str
    metadata: dict[str, Any] = Field(default_factory=dict)


class AreaNewsItem(BaseModel):
    id: str
    source: str
    category: str
    title: str
    summary: str
    url: str
    published_at: datetime
    city: str
    lat: float | None = None
    lng: float | None = None


class SourceStatus(BaseModel):
    name: str
    category: str
    endpoint: str
    last_success: datetime | None = None
    last_error: str | None = None
    event_count: int = 0
    news_count: int = 0


class RiskResponse(BaseModel):
    risk_score: float = Field(alias="riskScore", ge=0.0, le=1.0)
    classification: Literal["SAFE", "CAUTION", "DANGER"]
    risk_density: float = Field(alias="riskDensity", ge=0.0)
    contributing_events: int = Field(alias="contributingEvents", ge=0)
    eval_latency_ms: int = Field(alias="evalLatencyMs", ge=0)
    contributing_cells: list[str] = Field(default_factory=list, alias="contributingCells")
    score_components: dict[str, float] = Field(default_factory=dict, alias="scoreComponents")


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded"]
    namespace: str
    checked_at: datetime
    source_count: int


class TrafficReasonItem(BaseModel):
    reason: str
    category: str
    event_count: int = Field(alias="eventCount", ge=0)
    avg_severity: float = Field(alias="avgSeverity", ge=0.0, le=1.0)
    impact_score: float = Field(alias="impactScore", ge=0.0)
    sample_titles: list[str] = Field(default_factory=list, alias="sampleTitles")


class TrafficReasonResponse(BaseModel):
    city: str
    radius_km: float = Field(alias="radiusKm", ge=1.0, le=20.0)
    total_events: int = Field(alias="totalEvents", ge=0)
    reasons: list[TrafficReasonItem] = Field(default_factory=list)


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    d_lat = radians(lat2 - lat1)
    d_lng = radians(lng2 - lng1)
    a = sin(d_lat / 2.0) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lng / 2.0) ** 2
    c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
    return r * c


def _route_length_km(points: list[RoutePoint]) -> float:
    total = 0.0
    for i in range(1, len(points)):
        p0 = points[i - 1]
        p1 = points[i]
        total += _haversine_km(p0.lat, p0.lng, p1.lat, p1.lng)
    return total


class TrafficForecastRequest(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lng: float = Field(ge=-180.0, le=180.0)
    horizon_minutes: int = Field(default=15, ge=5, le=60)


class TrafficForecastResponse(BaseModel):
    lat: float
    lng: float
    forecast_5m: float = Field(alias="forecast5m", ge=0.0)
    forecast_15m: float = Field(alias="forecast15m", ge=0.0)
    forecast_30m: float = Field(alias="forecast30m", ge=0.0)
    congestion_level: Literal["FREE", "MODERATE", "HEAVY", "STANDSTILL"]
    generated_at: datetime = Field(alias="generatedAt")


class RouteNavigationRequest(BaseModel):
    origin: RoutePoint
    destination: RoutePoint
    mode: Literal["fastest", "shortest", "safest", "balanced"] = "balanced"


class NavigationStep(BaseModel):
    step_index: int = Field(alias="stepIndex", ge=0)
    instruction: str
    distance_m: float = Field(alias="distanceM", ge=0.0)
    duration_s: float = Field(alias="durationS", ge=0.0)


class RouteNavigationResponse(BaseModel):
    route_polyline: list[list[float]] = Field(alias="routePolyline")
    navigation_steps: list[NavigationStep] = Field(alias="navigationSteps")
    travel_time_s: float = Field(alias="travelTimeS", ge=0.0)
    distance_m: float = Field(alias="distanceM", ge=0.0)
    risk_score: float = Field(alias="riskScore", ge=0.0, le=1.0)
    estimated_arrival_iso: str = Field(alias="estimatedArrivalIso")


def now_utc() -> datetime:
    return datetime.now(timezone.utc)
