"""Daily protein target. Target stays the same under food limits; only sources change (F21)."""

from dataclasses import dataclass
from typing import Literal

from engine import constants as C


@dataclass(frozen=True)
class ProteinTarget:
    grams: int
    low_g: int
    high_g: int
    basis: Literal["bodyweight", "lean_mass"]


def protein_target(goal: str, weight_kg: float, body_fat_pct: float | None = None) -> ProteinTarget:
    """Fat loss with a known body-fat %: Helms 2014 band on lean mass, aim at the lower end.
    Otherwise: Morton 2018 breakpoint on bodyweight, with 2.2 g/kg as the top of the range.
    """
    if goal == "fat_loss" and body_fat_pct is not None:
        lbm = weight_kg * (1 - body_fat_pct / 100)
        low, high = (lbm * g for g in C.PROTEIN_CUT_G_PER_KG_LBM)
        return ProteinTarget(grams=round(low), low_g=round(low), high_g=round(high), basis="lean_mass")

    low = weight_kg * C.PROTEIN_GAIN_G_PER_KG
    high = weight_kg * C.PROTEIN_GAIN_UPPER_G_PER_KG
    return ProteinTarget(grams=round(low), low_g=round(low), high_g=round(high), basis="bodyweight")
