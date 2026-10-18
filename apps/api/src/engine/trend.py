"""Weight trend, weekly rate and the "Am I on track?" verdict (A12).

The rate is a least-squares slope over daily weigh-ins (regression already averages out water
swings). The EMA is only for drawing the trend line: it lags, so it would understate the rate.
"""

from dataclasses import dataclass
from datetime import date
from typing import Literal

from engine import constants as C


@dataclass(frozen=True)
class WeighIn:
    day: date
    kg: float
    excluded: bool = False  # unwell / travel days don't move the trend


def daily_points(weigh_ins: list[WeighIn]) -> list[tuple[date, float]]:
    """One point per included day; the last weigh-in of a day wins."""
    by_day: dict[date, float] = {}
    for w in sorted(weigh_ins, key=lambda w: w.day):
        if not w.excluded:
            by_day[w.day] = w.kg
    return sorted(by_day.items())


def slope_per_day(points: list[tuple[date, float]]) -> float:
    x0 = points[0][0]
    xs = [(d - x0).days for d, _ in points]
    ys = [kg for _, kg in points]
    mx, my = sum(xs) / len(xs), sum(ys) / len(ys)
    denom = sum((x - mx) ** 2 for x in xs)
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / denom


def smoothed_trend(weigh_ins: list[WeighIn]) -> list[tuple[date, float]]:
    """EMA for the chart line."""
    out: list[tuple[date, float]] = []
    ema: float | None = None
    for d, kg in daily_points(weigh_ins):
        ema = kg if ema is None else ema + C.WEIGHT_EMA_ALPHA * (kg - ema)
        out.append((d, ema))
    return out


@dataclass(frozen=True)
class Rate:
    enough_data: bool
    data_days: int
    kg_per_week: float | None = None
    pct_per_week: float | None = None


def weekly_rate(weigh_ins: list[WeighIn]) -> Rate:
    points = daily_points(weigh_ins)
    if len(points) < C.MIN_TREND_DAYS:
        return Rate(enough_data=False, data_days=len(points))
    kg_wk = slope_per_day(points) * 7
    mean_kg = sum(kg for _, kg in points) / len(points)
    return Rate(
        enough_data=True,
        data_days=len(points),
        kg_per_week=round(kg_wk, 3),
        pct_per_week=round(kg_wk / mean_kg * 100, 3),
    )


Verdict = Literal["not_enough_data", "on_pace", "too_slow", "too_fast", "wrong_direction"]

# Upper bound for "lean" muscle gain, %/wk. Design choice. status: verify
MUSCLE_GAIN_MAX_PCT = 0.5


def on_track(goal: str, rate: Rate) -> Verdict:
    """Fat loss: on pace inside the 0.5-1.0 %/wk band. Muscle gain: a slow gain above 0."""
    if not rate.enough_data or rate.pct_per_week is None:
        return "not_enough_data"
    p = rate.pct_per_week
    if goal == "fat_loss":
        if p >= 0:
            return "wrong_direction"
        if -p < C.FAT_LOSS_RATE_MIN:
            return "too_slow"
        return "too_fast" if -p > C.FAST_LOSS_FLAG else "on_pace"
    if p < 0:
        return "wrong_direction"
    if p == 0:
        return "too_slow"
    return "too_fast" if p > MUSCLE_GAIN_MAX_PCT else "on_pace"
