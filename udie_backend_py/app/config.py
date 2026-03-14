from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DB_PATH = str(BASE_DIR / "udie_state.db")


@dataclass(frozen=True)
class Settings:
    request_timeout_s: float = float(os.getenv("UDIE_REQUEST_TIMEOUT_S", "5.0"))
    source_cache_ttl_s: int = int(os.getenv("UDIE_SOURCE_CACHE_TTL_S", "120"))
    user_agent: str = os.getenv("UDIE_USER_AGENT", "udie-open-data/1.0")
    db_path: str = os.getenv("UDIE_DB_PATH", DEFAULT_DB_PATH)


settings = Settings()
