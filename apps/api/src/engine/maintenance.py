"""Adaptive maintenance estimate (A1): real maintenance from logged intake + weight trend.

maintenance ~= average intake - (weight slope in kg/day * KCAL_PER_KG).
Only days the user logged completely count, because under-logging is the most common reason
a stalled cut "isn't working" (Lichtman 1992).
"""

from dataclasses import dataclass
from datetime import date

from engine import constants as C
from engine.trend import WeighIn, daily_points, slope_per_day

MIN_COMPLETE_DAYS = 10
MIN_SPAN_DAYS = 7
FULL_CONFIDENCE_SPAN_DAYS = 28


@dataclass(frozen=True)
class IntakeDay:
    day: date
    kcal: float
    complete: bool  # log_confidence == complete (A4)


@dataclass(frozen=True)
class MaintenanceEstimate:
    kcal: float | None
    complete_days: int
    confidence: float  # 0-1: logging coverage x trend span
    reason: str | None = None  # why there is no estimate


def adaptive_maintenance(intake: list[IntakeDay], weigh_ins: list[WeighIn]) -> MaintenanceEstimate:
    complete = [d for d in intake if d.complete]
    if len(complete) < MIN_COMPLETE_DAYS:
        return MaintenanceEstimate(None, len(complete), 0.0, reason="not_enough_complete_logs")

    start, end = min(d.day for d in complete), max(d.day for d in complete)
    points = [(d, kg) for d, kg in daily_points(weigh_ins) if start <= d <= end]
    if len(points) < 2:
        return MaintenanceEstimate(None, len(complete), 0.0, reason="not_enough_weigh_ins")
    span_days = (points[-1][0] - points[0][0]).days
    if span_days < MIN_SPAN_DAYS:
        return MaintenanceEstimate(None, len(complete), 0.0, reason="window_too_short")

    avg_intake = sum(d.kcal for d in complete) / len(complete)
    kcal = avg_intake - slope_per_day(points) * C.KCAL_PER_KG

    coverage = len(complete) / ((end - start).days + 1)
    confidence = round(min(1.0, coverage) * min(1.0, span_days / FULL_CONFIDENCE_SPAN_DAYS), 2)
    return MaintenanceEstimate(round(kcal), len(complete), confidence)
