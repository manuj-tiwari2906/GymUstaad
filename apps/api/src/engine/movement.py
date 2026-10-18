"""F20 movement plan: ACSM walking energy and the weekly step ramp."""

from dataclasses import dataclass

from engine import constants as C


@dataclass(frozen=True)
class WalkEnergy:
    net_kcal: float
    in_valid_range: bool  # outside ~3-6 km/h the walking equation is not valid


def walking_kcal(weight_kg: float, speed_kmh: float, incline_pct: float, minutes: float) -> WalkEnergy:
    """Net kcal above rest (what the walk adds), always shown to users as an estimate."""
    s = speed_kmh * 1000 / 60
    g = incline_pct / 100
    vo2 = C.ACSM_REST + C.ACSM_HORIZONTAL * s + C.ACSM_VERTICAL * s * g
    net = (vo2 - C.ACSM_REST) * weight_kg / 1000 * C.KCAL_PER_L_O2 * minutes
    valid = C.ACSM_WALK_SPEED_MIN <= s <= C.ACSM_WALK_SPEED_MAX
    return WalkEnergy(net_kcal=round(net), in_valid_range=valid)


def step_target(baseline_steps: int, weeks_in: int, age: int) -> int:
    """+1,000/week from the person's own baseline, stopping at the Paluch 2022 plateau for their age."""
    ceiling = C.STEP_CEILING_60_PLUS if age >= 60 else C.STEP_CEILING_UNDER_60
    if baseline_steps >= ceiling:
        return baseline_steps  # never ask for less than they already do
    return min(baseline_steps + C.STEP_RAMP_PER_WEEK * weeks_in, ceiling)
