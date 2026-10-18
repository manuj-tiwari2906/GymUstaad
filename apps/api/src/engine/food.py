"""Food log numbers: oil rule C, raw/cooked guard, F21 hard filters."""

from dataclasses import dataclass
from typing import Literal

from engine import constants as C

Oil = Literal["less", "normal", "extra"]


@dataclass(frozen=True)
class KcalRange:
    low: float
    typ: float
    high: float


@dataclass(frozen=True)
class OilAdjusted:
    kcal: float
    oil_adjust_kcal: float
    clamped: bool


def apply_oil(r: KcalRange, oil: Oil) -> OilAdjusted:
    """Oil rule C: add/subtract a stated oil amount, never leaving the dish's measured range."""
    adjust = C.OIL_TBSP[oil] * C.KCAL_PER_TBSP_OIL
    raw = r.typ + adjust
    kcal = min(max(raw, r.low), r.high)
    return OilAdjusted(kcal=round(kcal), oil_adjust_kcal=round(kcal - r.typ), clamped=kcal != raw)


# Guard against raw weights logged as cooked. Thresholds are design choices. status: verify
SMALL_COOKED_G = {"rice": 100.0, "dal": 80.0}


def raw_cooked_guard(food_kind: str, state: str, grams: float) -> str | None:
    limit = SMALL_COOKED_G.get(food_kind)
    if limit is not None and state == "cooked" and grams <= limit:
        return f"small_cooked_{food_kind}"
    return None


# Food limit -> tag column. 'check' counts as contains, so a draft tag never lets a blocked food through.
LIMIT_TAG = {
    "lactose": "contains_lactose",
    "gluten": "contains_gluten",
    "nuts": "contains_nuts",
    "eggs": "contains_egg",
    "fish": "contains_fish",
    "soy": "contains_soy",
}
DIET_ALLOWS = {"veg": {"veg"}, "jain": {"veg"}, "egg": {"veg", "egg"}, "nonveg": {"veg", "egg", "nonveg"}}


def allowed(tags: dict[str, str], diet: str, limits: list[str]) -> bool:
    if tags["diet_type"] not in DIET_ALLOWS[diet]:
        return False
    if diet == "jain" and tags.get("jain_ok", "check") != "yes":
        return False
    return all(tags.get(LIMIT_TAG[lim], "check") == "no" for lim in limits)
