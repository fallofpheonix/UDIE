from __future__ import annotations


def categorize_issue(text: str, fallback: str = "general_disruption") -> str:
    t = text.lower()

    if _contains_any(
        t,
        {
            "construction",
            "street condition",
            "road closed",
            "road closure",
            "bridge",
            "utility work",
            "lane closed",
            "maintenance",
            "detour",
        },
    ):
        return "construction"

    if _contains_any(
        t,
        {
            "accident",
            "collision",
            "vehicle crash",
            "motor vehicle",
            "traffic incident",
            "wreck",
            "road incident",
        },
    ):
        return "accident"

    if _contains_any(
        t,
        {
            "gang",
            "assault",
            "battery",
            "shooting",
            "homicide",
            "violence",
            "armed",
            "weapon",
            "robbery",
            "riot",
        },
    ):
        return "gangfight_or_violence"

    if _contains_any(
        t,
        {
            "minister",
            "president",
            "prime minister",
            "motorcade",
            "vip",
            "dignitary",
            "parade",
            "summit",
            "high security",
            "official visit",
            "security lockdown",
        },
    ):
        return "vip_movement"

    if _contains_any(
        t,
        {
            "weather",
            "flood",
            "storm",
            "hurricane",
            "cyclone",
            "tornado",
            "wildfire",
            "earthquake",
            "landslide",
            "heat advisory",
            "blizzard",
        },
    ):
        return "weather_disruption"

    if _contains_any(
        t,
        {
            "evac",
            "civil emergency",
            "public safety",
            "shelter",
            "hazmat",
            "chemical",
        },
    ):
        return "public_safety"

    return fallback


def severity_for_category(category: str) -> float:
    if category in {"gangfight_or_violence", "vip_movement"}:
        return 0.85
    if category in {"accident", "construction", "weather_disruption", "public_safety"}:
        return 0.65
    return 0.45


def _contains_any(text: str, keywords: set[str]) -> bool:
    return any(k in text for k in keywords)
