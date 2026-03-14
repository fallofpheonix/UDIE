from __future__ import annotations

from datetime import datetime
from typing import Any

import httpx

from app.models import AreaNewsItem, BoundingBox, DisruptionEvent, now_utc
from app.sources.base import GovernmentSource, SourceResult
from app.sources.classifier import categorize_issue, severity_for_category


class NdmaSachetAlertSource(GovernmentSource):
    name = "NDMA Sachet Alerts"
    category = "public_safety"
    endpoint = "https://sachet.ndma.gov.in/cap_public_website/FetchAllAlertDetails"

    async def fetch(self, client: httpx.AsyncClient, area: BoundingBox) -> SourceResult:
        try:
            resp = await client.get(self.endpoint)
            resp.raise_for_status()
            payload = resp.json()
        except Exception as exc:  # noqa: BLE001
            return SourceResult(events=[], news=[], error=str(exc))

        if not isinstance(payload, list):
            return SourceResult(events=[], news=[], error="Invalid NDMA payload")

        events: list[DisruptionEvent] = []
        news: list[AreaNewsItem] = []
        for row in payload:
            if not isinstance(row, dict):
                continue
            lat, lng = _parse_centroid(row.get("centroid"))
            if lat is None or lng is None or not _in_bbox(lat, lng, area):
                continue

            identifier = str(row.get("identifier") or row.get("alert_id_sdma_autoinc") or now_utc().timestamp())
            disaster_type = str(row.get("disaster_type") or "Alert")
            warning_message = str(row.get("warning_message") or "")
            area_desc = str(row.get("area_description") or "")
            severity_color = str(row.get("severity_color") or "yellow")
            title = f"{disaster_type} - {area_desc}" if area_desc else disaster_type
            category = categorize_issue(f"{disaster_type} {warning_message} {area_desc}", fallback="public_safety")
            severity = _severity_from_ndma(severity_color, category)
            effective_start = str(row.get("effective_start_time") or "")
            effective_end = str(row.get("effective_end_time") or "")
            updated_at = _parse_ndma_time(effective_start) or now_utc().isoformat()

            metadata = {
                "severity": str(row.get("severity") or ""),
                "severityLevel": str(row.get("severity_level") or ""),
                "effectiveStart": effective_start,
                "effectiveEnd": effective_end,
                "areaDescription": area_desc,
                "alertSource": str(row.get("alert_source") or "NDMA"),
                "url": "https://sachet.ndma.gov.in/",
            }

            events.append(
                DisruptionEvent(
                    id=f"ndma-{identifier}",
                    source=self.name,
                    category=category,
                    title=title,
                    lat=lat,
                    lng=lng,
                    severity=severity,
                    updated_at=updated_at,
                    city=area.city,
                    metadata=metadata,
                )
            )
            news.append(
                AreaNewsItem(
                    id=f"news-ndma-{identifier}",
                    source=self.name,
                    category=category,
                    title=title,
                    summary=(warning_message[:280] if warning_message else "NDMA alert in monitored area."),
                    url="https://sachet.ndma.gov.in/",
                    published_at=updated_at,
                    city=area.city,
                    lat=lat,
                    lng=lng,
                )
            )

        return SourceResult(events=events, news=news)


class NdmaLocationAlertSource(GovernmentSource):
    name = "NDMA Localized Alerts"
    category = "public_safety"
    endpoint = "https://sachet.ndma.gov.in/cap_public_website/FetchLocationWiseAlerts"

    async def fetch(self, client: httpx.AsyncClient, area: BoundingBox) -> SourceResult:
        center_lat = (area.min_lat + area.max_lat) / 2.0
        center_lng = (area.min_lng + area.max_lng) / 2.0
        radius = _radius_from_area_km(area)

        try:
            resp = await client.post(
                self.endpoint,
                params={"lat": f"{center_lat:.6f}", "long": f"{center_lng:.6f}", "radius": str(radius)},
                headers={"content-Type": "application/json"},
            )
            resp.raise_for_status()
            payload = resp.json()
        except Exception as exc:  # noqa: BLE001
            return SourceResult(events=[], news=[], error=str(exc))

        alerts = payload.get("alerts") if isinstance(payload, dict) else None
        if not isinstance(alerts, list):
            return SourceResult(events=[], news=[])

        events: list[DisruptionEvent] = []
        news: list[AreaNewsItem] = []
        for row in alerts:
            if not isinstance(row, dict):
                continue
            lat, lng = _parse_centroid(row.get("centroid"))
            if lat is None or lng is None:
                lat, lng = center_lat, center_lng
            if not _in_bbox(lat, lng, area):
                continue

            identifier = str(row.get("identifier") or row.get("alert_id_sdma_autoinc") or now_utc().timestamp())
            disaster_type = str(row.get("disaster_type") or "Alert")
            warning_message = str(row.get("warning_message") or "")
            area_desc = str(row.get("area_description") or "")
            severity_color = str(row.get("severity_color") or "yellow")
            title = f"{disaster_type} - {area_desc}" if area_desc else disaster_type
            category = categorize_issue(f"{disaster_type} {warning_message} {area_desc}", fallback="public_safety")
            severity = _severity_from_ndma(severity_color, category)
            updated_at = _parse_ndma_time(str(row.get("effective_start_time") or "")) or now_utc().isoformat()

            events.append(
                DisruptionEvent(
                    id=f"ndma-local-{identifier}",
                    source=self.name,
                    category=category,
                    title=title,
                    lat=lat,
                    lng=lng,
                    severity=severity,
                    updated_at=updated_at,
                    city=area.city,
                    metadata={
                        "areaDescription": area_desc,
                        "effectiveEnd": str(row.get("effective_end_time") or ""),
                        "url": "https://sachet.ndma.gov.in/",
                    },
                )
            )
            news.append(
                AreaNewsItem(
                    id=f"news-ndma-local-{identifier}",
                    source=self.name,
                    category=category,
                    title=title,
                    summary=(warning_message[:280] if warning_message else "Localized NDMA alert."),
                    url="https://sachet.ndma.gov.in/",
                    published_at=updated_at,
                    city=area.city,
                    lat=lat,
                    lng=lng,
                )
            )

        return SourceResult(events=events, news=news)


class NdmaStateDashboardSource(GovernmentSource):
    name = "NDMA State Dashboard"
    category = "public_safety"
    endpoint = "https://sachet.ndma.gov.in/cap_public_website/FetchDashboardData"

    async def fetch(self, client: httpx.AsyncClient, area: BoundingBox) -> SourceResult:
        state = _state_for_city(area.city)
        if state is None:
            return SourceResult(events=[], news=[])
        try:
            resp = await client.get(self.endpoint)
            resp.raise_for_status()
            payload = resp.json()
        except Exception as exc:  # noqa: BLE001
            return SourceResult(events=[], news=[], error=str(exc))

        rows = payload.get("statewise") if isinstance(payload, dict) else None
        if not isinstance(rows, list):
            return SourceResult(events=[], news=[], error="Invalid NDMA dashboard payload")

        matched = None
        for row in rows:
            if not isinstance(row, dict):
                continue
            if str(row.get("state", "")).strip().lower() == state.lower():
                matched = row
                break
        if matched is None:
            return SourceResult(events=[], news=[])

        alert_stats = matched.get("alertStatistics") if isinstance(matched.get("alertStatistics"), dict) else {}
        red = int(alert_stats.get("red_alerts") or 0)
        orange = int(alert_stats.get("orange_alerts") or 0)
        yellow = int(alert_stats.get("yellow_alerts") or 0)
        total = int(alert_stats.get("total_alerts") or (red + orange + yellow))
        if total <= 0:
            return SourceResult(events=[], news=[])

        weighted = (red * 1.0 + orange * 0.6 + yellow * 0.35) / max(1, total)
        severity = max(0.20, min(0.98, weighted))
        center_lat = (area.min_lat + area.max_lat) / 2.0
        center_lng = (area.min_lng + area.max_lng) / 2.0
        stamp = now_utc().strftime("%Y%m%d%H")
        title = f"{state} State Alert Pressure"
        summary = f"NDMA state alerts for {state}: red={red}, orange={orange}, yellow={yellow}, total={total}."

        event = DisruptionEvent(
            id=f"ndma-state-{state.lower().replace(' ', '-')}-{stamp}",
            source=self.name,
            category="public_safety",
            title=title,
            lat=center_lat,
            lng=center_lng,
            severity=severity,
            updated_at=now_utc().isoformat(),
            city=area.city,
            metadata={
                "state": state,
                "redAlerts": red,
                "orangeAlerts": orange,
                "yellowAlerts": yellow,
                "totalAlerts": total,
                "url": "https://sachet.ndma.gov.in/",
            },
        )
        news = AreaNewsItem(
            id=f"news-{event.id}",
            source=self.name,
            category="public_safety",
            title=title,
            summary=summary,
            url="https://sachet.ndma.gov.in/",
            published_at=now_utc().isoformat(),
            city=area.city,
            lat=center_lat,
            lng=center_lng,
        )
        return SourceResult(events=[event], news=[news])


def _radius_from_area_km(area: BoundingBox) -> int:
    lat_span_km = abs(area.max_lat - area.min_lat) * 111.0
    lng_span_km = abs(area.max_lng - area.min_lng) * 111.0
    return max(5, min(50, int(max(lat_span_km, lng_span_km) / 2)))


def _parse_centroid(value: Any) -> tuple[float | None, float | None]:
    if not isinstance(value, str) or "," not in value:
        return None, None
    parts = value.split(",")
    if len(parts) < 2:
        return None, None
    try:
        lng = float(parts[0].strip())
        lat = float(parts[1].strip())
    except ValueError:
        return None, None
    return lat, lng


def _parse_ndma_time(value: str) -> str | None:
    raw = value.strip()
    if not raw:
        return None
    for fmt in ("%a %b %d %H:%M:%S IST %Y", "%a %b %d %H:%M:%S %Z %Y"):
        try:
            dt = datetime.strptime(raw, fmt)
            return dt.isoformat()
        except ValueError:
            continue
    return None


def _severity_from_ndma(color: str, category: str) -> float:
    c = color.lower().strip()
    table = {
        "red": 0.95,
        "orange": 0.80,
        "yellow": 0.60,
        "green": 0.35,
    }
    return table.get(c, severity_for_category(category))


def _in_bbox(lat: float, lng: float, area: BoundingBox) -> bool:
    return area.min_lat <= lat <= area.max_lat and area.min_lng <= lng <= area.max_lng


CITY_TO_STATE = {
    "new delhi": "Delhi",
    "delhi": "Delhi",
    "mumbai": "Maharashtra",
    "bengaluru": "Karnataka",
    "bangalore": "Karnataka",
    "chennai": "Tamil Nadu",
    "hyderabad": "Telangana",
    "kolkata": "West Bengal",
    "pune": "Maharashtra",
    "ahmedabad": "Gujarat",
    "jaipur": "Rajasthan",
    "lucknow": "Uttar Pradesh",
    "bhopal": "Madhya Pradesh",
    "patna": "Bihar",
    "guwahati": "Assam",
    "chandigarh": "Chandigarh",
    "srinagar": "Jammu and Kashmir",
    "kochi": "Kerala",
    "thiruvananthapuram": "Kerala",
    "nagpur": "Maharashtra",
    "indore": "Madhya Pradesh",
    "surat": "Gujarat",
    "kanpur": "Uttar Pradesh",
    "varanasi": "Uttar Pradesh",
    "visakhapatnam": "Andhra Pradesh",
    "coimbatore": "Tamil Nadu",
    "madurai": "Tamil Nadu",
}


def _state_for_city(city: str) -> str | None:
    return CITY_TO_STATE.get(city.strip().lower())
