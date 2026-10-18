"""Weekly hard sets per muscle region (F2), using exercise -> region contribution weights."""

from collections import defaultdict
from dataclasses import dataclass
from typing import Literal

from engine import constants as C


@dataclass(frozen=True)
class SetLog:
    exercise_id: str
    rir: int  # 0, 1, 2, 3 (3 means "3+")


def is_hard(s: SetLog) -> bool:
    return s.rir <= C.HARD_SET_MAX_RIR


def weekly_sets_by_region(
    sets: list[SetLog], contribution: dict[str, dict[str, float]]
) -> dict[str, float]:
    """contribution: exercise_id -> {region_code: 0..1}. Exercises missing from the map are skipped."""
    totals: dict[str, float] = defaultdict(float)
    for s in sets:
        if not is_hard(s):
            continue
        for region, weight in contribution.get(s.exercise_id, {}).items():
            totals[region] += weight
    return {r: round(v, 1) for r, v in totals.items()}


Band = Literal["below", "in", "above"]


def volume_band(sets: float, low: int = C.WEEKLY_SETS_LOW, high: int = C.WEEKLY_SETS_HIGH) -> Band:
    """Default 12-20. Callers pass the user's individual band once it has been adjusted (Scarpelli 2020)."""
    if sets < low:
        return "below"
    return "above" if sets > high else "in"
