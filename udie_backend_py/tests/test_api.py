from pathlib import Path
import sys

from fastapi.testclient import TestClient

sys.path.append(str(Path(__file__).resolve().parents[1]))

from app.main import app


client = TestClient(app)


def test_health_namespace_api() -> None:
    resp = client.get("/api/health")
    assert resp.status_code == 200
    payload = resp.json()
    assert payload["status"] == "ok"
    assert payload["namespace"] == "/api"


def test_health_namespace_v1() -> None:
    resp = client.get("/api/v1/health")
    assert resp.status_code == 200
    payload = resp.json()
    assert payload["status"] == "ok"
    assert payload["namespace"] == "/api/v1"


def test_events_requires_contract() -> None:
    resp = client.get("/api/events")
    assert resp.status_code == 422


def test_news_by_radius_contract_valid() -> None:
    resp = client.get(
        "/api/news",
        params={"city": "Delhi", "lat": 28.6139, "lng": 77.2090, "radiusKm": 10, "limit": 5},
    )
    assert resp.status_code == 200
    payload = resp.json()
    assert isinstance(payload, list)
    assert len(payload) <= 5


def test_traffic_reasons_contract_valid() -> None:
    resp = client.get(
        "/api/traffic-reasons",
        params={"city": "Delhi", "lat": 28.6139, "lng": 77.2090, "radiusKm": 10, "limit": 5},
    )
    assert resp.status_code == 200
    payload = resp.json()
    assert payload["city"] == "Delhi"
    assert "reasons" in payload
    assert isinstance(payload["reasons"], list)
    if payload["reasons"]:
        row = payload["reasons"][0]
        assert "reason" in row
        assert "impactScore" in row
        assert "eventCount" in row


def test_reject_non_indian_city() -> None:
    resp = client.get(
        "/api/news",
        params={"city": "InvalidCity", "lat": 41.8781, "lng": -87.6298, "radiusKm": 10},
    )
    assert resp.status_code == 422


def test_reject_out_of_india_bbox_even_with_indian_city() -> None:
    resp = client.get(
        "/api/events",
        params={
            "city": "Delhi",
            "minLat": 40.0,
            "maxLat": 41.0,
            "minLng": -75.0,
            "maxLng": -74.0,
        },
    )
    assert resp.status_code == 422


def test_health_ready_contract() -> None:
    resp = client.get("/api/health/ready")
    assert resp.status_code == 200
    payload = resp.json()
    assert payload["status"] in {"ok", "degraded"}
    assert "riskCells" in payload


def test_risk_route_limit_enforced() -> None:
    resp = client.post(
        "/api/risk",
        json={
            "coordinates": [
                {"lat": 0.0, "lng": 0.0},
                {"lat": 0.8, "lng": 0.8},
            ]
        },
    )
    assert resp.status_code == 422
