from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))

from app.sources.classifier import categorize_issue, severity_for_category


def test_category_mapping_keywords() -> None:
    assert categorize_issue("major road construction and bridge work") == "construction"
    assert categorize_issue("motor vehicle accident near junction") == "accident"
    assert categorize_issue("gang assault reported") == "gangfight_or_violence"
    assert categorize_issue("minister motorcade and high security zone") == "vip_movement"


def test_severity_mapping() -> None:
    assert severity_for_category("gangfight_or_violence") > severity_for_category("general_disruption")
