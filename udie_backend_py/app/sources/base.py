from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass

import httpx

from app.models import AreaNewsItem, BoundingBox, DisruptionEvent


@dataclass(frozen=True)
class SourceResult:
    events: list[DisruptionEvent]
    news: list[AreaNewsItem]
    error: str | None = None


class GovernmentSource(ABC):
    name: str
    category: str
    endpoint: str

    @abstractmethod
    async def fetch(self, client: httpx.AsyncClient, area: BoundingBox) -> SourceResult:
        raise NotImplementedError
