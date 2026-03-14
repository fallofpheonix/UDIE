from __future__ import annotations

import json
import math
import sqlite3
import threading
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

from app.config import settings
from app.models import AreaNewsItem, BoundingBox, DisruptionEvent, RoutePoint, now_utc


def _resolve_db_path(raw: str) -> Path:
    candidate = Path(raw).expanduser()
    if not candidate.is_absolute():
        candidate = Path(__file__).resolve().parents[1] / candidate
    candidate.parent.mkdir(parents=True, exist_ok=True)
    return candidate


DB_PATH = _resolve_db_path(settings.db_path)
CELL_STEP = 0.01
MERGE_DISTANCE_KM = 0.025
MERGE_WINDOW_SECONDS = 30 * 60
EXPIRY_CONFIDENCE = 0.15
DECAY_TAU_HOURS = 24.0


@dataclass
class RouteCell:
    cell_id: str
    lat: float
    lng: float


class UdieStore:
    def __init__(self, path: Path = DB_PATH) -> None:
        self._path = path
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(str(path), check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._init_schema()

    def _init_schema(self) -> None:
        with self._lock:
            cur = self._conn.cursor()
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS events_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    source_event_id TEXT NOT NULL,
                    source TEXT NOT NULL,
                    category TEXT NOT NULL,
                    title TEXT NOT NULL,
                    lat REAL NOT NULL,
                    lng REAL NOT NULL,
                    severity REAL NOT NULL,
                    updated_at TEXT NOT NULL,
                    city TEXT NOT NULL,
                    metadata_json TEXT NOT NULL,
                    ingested_at TEXT NOT NULL,
                    UNIQUE(source_event_id, source, updated_at)
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS events_active (
                    active_id TEXT PRIMARY KEY,
                    source TEXT NOT NULL,
                    category TEXT NOT NULL,
                    title TEXT NOT NULL,
                    lat REAL NOT NULL,
                    lng REAL NOT NULL,
                    confidence REAL NOT NULL,
                    first_seen TEXT NOT NULL,
                    last_seen TEXT NOT NULL,
                    city TEXT NOT NULL,
                    metadata_json TEXT NOT NULL
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS risk_cells (
                    cell_id TEXT PRIMARY KEY,
                    lat REAL NOT NULL,
                    lng REAL NOT NULL,
                    risk REAL NOT NULL,
                    event_count INTEGER NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS system_state (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )
            self._conn.commit()

    def append_events_log(self, events: list[DisruptionEvent]) -> list[DisruptionEvent]:
        ingested: list[DisruptionEvent] = []
        ts = now_utc().isoformat()
        with self._lock:
            cur = self._conn.cursor()
            for event in events:
                cur.execute(
                    """
                    INSERT OR IGNORE INTO events_log
                    (source_event_id, source, category, title, lat, lng, severity, updated_at, city, metadata_json, ingested_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        event.id,
                        event.source,
                        event.category,
                        event.title,
                        event.lat,
                        event.lng,
                        float(event.severity),
                        event.updated_at.astimezone(UTC).isoformat(),
                        event.city,
                        json.dumps(event.metadata),
                        ts,
                    ),
                )
                if cur.rowcount > 0:
                    ingested.append(event)
            self._set_state_locked("last_ingest_count", str(len(ingested)))
            self._conn.commit()
        return ingested

    def project_lifecycle(self, events: list[DisruptionEvent]) -> None:
        with self._lock:
            cur = self._conn.cursor()
            active_rows = cur.execute("SELECT * FROM events_active").fetchall()
            active = [dict(r) for r in active_rows]
            incoming = list(events)

            # Projection bootstrap: if active state is empty but ledger exists, reconstruct from ledger.
            if not active and not incoming:
                logs = cur.execute("SELECT * FROM events_log ORDER BY id ASC LIMIT 5000").fetchall()
                incoming = [self._row_to_event(r) for r in logs]

            for event in incoming:
                event_dt = _ensure_utc(event.updated_at)
                match = self._find_active_match(active, event)
                if match is None:
                    active_id = f"a-{uuid.uuid4()}"
                    item = {
                        "active_id": active_id,
                        "source": event.source,
                        "category": event.category,
                        "title": event.title,
                        "lat": event.lat,
                        "lng": event.lng,
                        "confidence": float(max(0.05, min(1.0, event.severity))),
                        "first_seen": event_dt.isoformat(),
                        "last_seen": event_dt.isoformat(),
                        "city": event.city,
                        "metadata_json": json.dumps(event.metadata),
                    }
                    active.append(item)
                    cur.execute(
                        """
                        INSERT INTO events_active
                        (active_id, source, category, title, lat, lng, confidence, first_seen, last_seen, city, metadata_json)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            item["active_id"],
                            item["source"],
                            item["category"],
                            item["title"],
                            item["lat"],
                            item["lng"],
                            item["confidence"],
                            item["first_seen"],
                            item["last_seen"],
                            item["city"],
                            item["metadata_json"],
                        ),
                    )
                else:
                    new_conf = float(min(1.0, float(match["confidence"]) + float(event.severity) * 0.35))
                    last_seen = max(_parse_dt(match["last_seen"]), event_dt).astimezone(UTC).isoformat()
                    match["confidence"] = new_conf
                    match["last_seen"] = last_seen
                    cur.execute(
                        "UPDATE events_active SET confidence=?, last_seen=? WHERE active_id=?",
                        (new_conf, last_seen, match["active_id"]),
                    )

            self._apply_decay_locked(cur)
            cur.execute("DELETE FROM events_active WHERE confidence < ?", (EXPIRY_CONFIDENCE,))
            self._materialize_risk_cells_locked(cur)
            self._set_state_locked("last_projection_status", "ok")
            self._set_state_locked("last_projection_at", now_utc().isoformat())
            self._conn.commit()

    def rebuild_from_log(self) -> dict[str, int]:
        with self._lock:
            cur = self._conn.cursor()
            logs = cur.execute("SELECT * FROM events_log ORDER BY id ASC").fetchall()
            cur.execute("DELETE FROM events_active")
            cur.execute("DELETE FROM risk_cells")
            self._conn.commit()

        reconstructed = [self._row_to_event(r) for r in logs]
        self.project_lifecycle(reconstructed)
        return {"events_log": len(reconstructed), "events_active": len(self.get_active_events(None)), "risk_cells": self.count_risk_cells()}

    def get_active_events(self, area: BoundingBox | None, limit: int = 2000) -> list[DisruptionEvent]:
        with self._lock:
            cur = self._conn.cursor()
            if area is None:
                rows = cur.execute("SELECT * FROM events_active ORDER BY confidence DESC, last_seen DESC LIMIT ?", (limit,)).fetchall()
            else:
                rows = cur.execute(
                    """
                    SELECT * FROM events_active
                    WHERE lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?
                    ORDER BY confidence DESC, last_seen DESC
                    LIMIT ?
                    """,
                    (area.min_lat, area.max_lat, area.min_lng, area.max_lng, limit),
                ).fetchall()

        return [
            DisruptionEvent(
                id=str(r["active_id"]),
                source=str(r["source"]),
                category=str(r["category"]),
                title=str(r["title"]),
                lat=float(r["lat"]),
                lng=float(r["lng"]),
                severity=float(r["confidence"]),
                updated_at=r["last_seen"],
                city=str(r["city"]),
                metadata=json.loads(str(r["metadata_json"])),
            )
            for r in rows
        ]

    def get_area_news(self, area: BoundingBox, limit: int = 2000) -> list[AreaNewsItem]:
        with self._lock:
            cur = self._conn.cursor()
            rows = cur.execute(
                """
                SELECT * FROM events_log
                WHERE lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?
                ORDER BY updated_at DESC
                LIMIT ?
                """,
                (area.min_lat, area.max_lat, area.min_lng, area.max_lng, limit),
            ).fetchall()

        return [
            AreaNewsItem(
                id=f"news-log-{r['id']}",
                source=str(r["source"]),
                category=str(r["category"]),
                title=str(r["title"]),
                summary=f"Observation from {r['source']} in monitored area.",
                url=str(json.loads(str(r["metadata_json"])).get("url", "")),
                published_at=str(r["updated_at"]),
                city=str(r["city"]),
                lat=float(r["lat"]),
                lng=float(r["lng"]),
            )
            for r in rows
        ]

    def get_cell_insight(self, cell_id: str) -> dict[str, object] | None:
        with self._lock:
            cur = self._conn.cursor()
            row = cur.execute("SELECT * FROM risk_cells WHERE cell_id=?", (cell_id,)).fetchone()
            if row is None:
                return None
            lat = float(row["lat"])
            lng = float(row["lng"])
            events = cur.execute(
                """
                SELECT * FROM events_active
                WHERE lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?
                ORDER BY confidence DESC, last_seen DESC
                LIMIT 25
                """,
                (lat - 2 * CELL_STEP, lat + 2 * CELL_STEP, lng - 2 * CELL_STEP, lng + 2 * CELL_STEP),
            ).fetchall()

        contributors = [
            {
                "activeId": str(r["active_id"]),
                "title": str(r["title"]),
                "category": str(r["category"]),
                "confidence": float(r["confidence"]),
                "lastSeen": str(r["last_seen"]),
            }
            for r in events
        ]
        return {
            "cellId": str(row["cell_id"]),
            "risk": float(row["risk"]),
            "eventCount": int(row["event_count"]),
            "updatedAt": str(row["updated_at"]),
            "contributors": contributors,
        }

    def get_route_cell_values(self, points: list[RoutePoint]) -> list[tuple[RouteCell, float]]:
        route_cells = _route_to_cells(points)
        cell_ids = [cell.cell_id for cell in route_cells]
        if not cell_ids:
            return []

        placeholders = ",".join("?" for _ in cell_ids)
        with self._lock:
            cur = self._conn.cursor()
            rows = cur.execute(
                f"SELECT cell_id, risk FROM risk_cells WHERE cell_id IN ({placeholders})",  # noqa: S608
                cell_ids,
            ).fetchall()

        lookup = {str(r["cell_id"]): float(r["risk"]) for r in rows}
        return [(cell, lookup.get(cell.cell_id, 0.0)) for cell in route_cells]

    def count_risk_cells(self) -> int:
        with self._lock:
            cur = self._conn.cursor()
            row = cur.execute("SELECT COUNT(*) AS c FROM risk_cells").fetchone()
            return int(row["c"] if row else 0)

    def readiness(self) -> dict[str, object]:
        with self._lock:
            cur = self._conn.cursor()
            try:
                cur.execute("SELECT 1")
                db_ok = True
            except sqlite3.Error:
                db_ok = False
            state = {
                r["key"]: r["value"]
                for r in cur.execute("SELECT key, value FROM system_state").fetchall()
            }
        return {
            "db": "ok" if db_ok else "error",
            "lastProjectionStatus": state.get("last_projection_status", "unknown"),
            "lastProjectionAt": state.get("last_projection_at", "never"),
            "riskCells": self.count_risk_cells(),
        }

    def _find_active_match(self, active: list[dict[str, object]], event: DisruptionEvent) -> dict[str, object] | None:
        event_dt = _ensure_utc(event.updated_at)
        for item in active:
            if str(item["category"]) != event.category:
                continue
            if str(item["city"]).lower() != event.city.lower():
                continue
            d_km = _haversine_km(float(item["lat"]), float(item["lng"]), event.lat, event.lng)
            if d_km > MERGE_DISTANCE_KM:
                continue
            dt_seconds = abs((_parse_dt(str(item["last_seen"])) - event_dt).total_seconds())
            if dt_seconds > MERGE_WINDOW_SECONDS:
                continue
            return item
        return None

    def _apply_decay_locked(self, cur: sqlite3.Cursor) -> None:
        last_decay = self._get_state_locked("last_decay_at")
        now = now_utc()
        if last_decay is None:
            self._set_state_locked("last_decay_at", now.isoformat())
            return

        elapsed_h = max(0.0, (now - _parse_dt(last_decay)).total_seconds() / 3600.0)
        if elapsed_h <= 0.0:
            return

        factor = math.exp(-elapsed_h / DECAY_TAU_HOURS)
        cur.execute("UPDATE events_active SET confidence = confidence * ?", (factor,))
        self._set_state_locked("last_decay_at", now.isoformat())

    def _materialize_risk_cells_locked(self, cur: sqlite3.Cursor) -> None:
        started = now_utc()
        rows = cur.execute("SELECT lat, lng, confidence FROM events_active").fetchall()

        cells: dict[str, dict[str, float]] = {}
        for r in rows:
            lat = float(r["lat"])
            lng = float(r["lng"])
            conf = float(r["confidence"])
            base_lat = _snap(lat)
            base_lng = _snap(lng)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    c_lat = round(base_lat + dx * CELL_STEP, 5)
                    c_lng = round(base_lng + dy * CELL_STEP, 5)
                    cid = _cell_id(c_lat, c_lng)
                    dist = math.sqrt(dx * dx + dy * dy)
                    influence = conf * math.exp(-dist / 1.2)
                    slot = cells.setdefault(cid, {"lat": c_lat, "lng": c_lng, "sum": 0.0, "count": 0.0})
                    slot["sum"] += influence
                    slot["count"] += 1.0

        cur.execute("DELETE FROM risk_cells")
        for cid, payload in cells.items():
            risk = max(0.0, min(1.0, 1.0 - math.exp(-float(payload["sum"]))))
            cur.execute(
                """
                INSERT INTO risk_cells (cell_id, lat, lng, risk, event_count, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    cid,
                    float(payload["lat"]),
                    float(payload["lng"]),
                    risk,
                    int(payload["count"]),
                    started.isoformat(),
                ),
            )

        duration_ms = int((now_utc() - started).total_seconds() * 1000)
        self._set_state_locked("last_materialization_duration_ms", str(duration_ms))
        self._set_state_locked("last_materialization_status", "ok")

    def _row_to_event(self, row: sqlite3.Row) -> DisruptionEvent:
        return DisruptionEvent(
            id=str(row["source_event_id"]),
            source=str(row["source"]),
            category=str(row["category"]),
            title=str(row["title"]),
            lat=float(row["lat"]),
            lng=float(row["lng"]),
            severity=float(row["severity"]),
            updated_at=str(row["updated_at"]),
            city=str(row["city"]),
            metadata=json.loads(str(row["metadata_json"])),
        )

    def _get_state_locked(self, key: str) -> str | None:
        cur = self._conn.cursor()
        row = cur.execute("SELECT value FROM system_state WHERE key=?", (key,)).fetchone()
        return str(row["value"]) if row else None

    def _set_state_locked(self, key: str, value: str) -> None:
        cur = self._conn.cursor()
        cur.execute(
            """
            INSERT INTO system_state (key, value, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at
            """,
            (key, value, now_utc().isoformat()),
        )


def _parse_dt(value: str) -> datetime:
    v = value.strip()
    if v.endswith("Z"):
        v = v[:-1] + "+00:00"
    dt = datetime.fromisoformat(v)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def _ensure_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _snap(v: float) -> float:
    return round(round(v / CELL_STEP) * CELL_STEP, 5)


def _cell_id(lat: float, lng: float) -> str:
    return f"r9:{lat:.5f}:{lng:.5f}"


def _route_to_cells(points: list[RoutePoint]) -> list[RouteCell]:
    sampled: list[tuple[float, float]] = []
    for idx in range(1, len(points)):
        a = points[idx - 1]
        b = points[idx]
        segment_km = _haversine_km(a.lat, a.lng, b.lat, b.lng)
        steps = max(1, int(segment_km / 0.5))
        for s in range(steps + 1):
            t = s / steps
            lat = a.lat + (b.lat - a.lat) * t
            lng = a.lng + (b.lng - a.lng) * t
            sampled.append((lat, lng))

    seen: set[str] = set()
    cells: list[RouteCell] = []
    for lat, lng in sampled:
        slat = _snap(lat)
        slng = _snap(lng)
        cid = _cell_id(slat, slng)
        if cid in seen:
            continue
        seen.add(cid)
        cells.append(RouteCell(cell_id=cid, lat=slat, lng=slng))
    return cells


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = math.sin(d_lat / 2.0) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(d_lng / 2.0) ** 2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return r * c


store = UdieStore()
