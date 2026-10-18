"""Calorie targets: BMR, first-guess maintenance, goal targets with guardrails."""

from dataclasses import dataclass
from typing import Literal

from engine import constants as C

Sex = Literal["male", "female"]
DayType = Literal["desk", "mixed", "on_feet"]
Goal = Literal["muscle_gain", "fat_loss"]


def bmr_mifflin(weight_kg: float, height_cm: float, age: int, sex: Sex) -> float:
    base = C.MSJ_WEIGHT * weight_kg + C.MSJ_HEIGHT * height_cm - C.MSJ_AGE * age
    return base + (C.MSJ_MALE if sex == "male" else C.MSJ_FEMALE)


def initial_maintenance(weight_kg: float, height_cm: float, age: int, sex: Sex, day_type: DayType) -> float:
    """First guess only. Replaced by maintenance.adaptive_maintenance once logs exist."""
    return bmr_mifflin(weight_kg, height_cm, age, sex) * C.ACTIVITY_FACTOR[day_type]


@dataclass(frozen=True)
class KcalTarget:
    kcal: float
    rate_pct_per_week: float  # signed: negative = loss
    floored: bool  # True when the guardrail raised the target


def goal_target(
    goal: Goal,
    maintenance_kcal: float,
    weight_kg: float,
    bmr: float,
    sex: Sex,
    loss_rate_pct: float = C.FAT_LOSS_RATE_DEFAULT,
) -> KcalTarget:
    """Daily kcal target for the goal.

    Fat loss: deficit sized to lose `loss_rate_pct` of bodyweight per week, clamped to the
    0.5-1.0 band. Never below max(sex floor, BMR) (blueprint disordered-eating guardrail).
    """
    if goal == "muscle_gain":
        kcal = maintenance_kcal * (1 + C.MUSCLE_GAIN_SURPLUS_PCT)
        return KcalTarget(kcal=round(kcal), rate_pct_per_week=0.0, floored=False)

    rate = min(max(loss_rate_pct, C.FAT_LOSS_RATE_MIN), C.FAT_LOSS_RATE_MAX)
    daily_deficit = weight_kg * rate / 100 * C.KCAL_PER_KG / 7
    kcal = maintenance_kcal - daily_deficit
    floor = max(C.KCAL_FLOOR[sex], bmr)
    if kcal < floor:
        # Report the rate the floored target actually implies.
        actual_rate = (maintenance_kcal - floor) * 7 / C.KCAL_PER_KG / weight_kg * 100
        return KcalTarget(kcal=round(floor), rate_pct_per_week=-round(max(actual_rate, 0), 2), floored=True)
    return KcalTarget(kcal=round(kcal), rate_pct_per_week=-rate, floored=False)
