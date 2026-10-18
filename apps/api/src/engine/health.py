"""Body-composition flag at intake (A3) and the F21 "Not feeling well" phase rules."""

from typing import Literal

from engine import constants as C


def bmi(weight_kg: float, height_cm: float) -> float:
    return weight_kg / (height_cm / 100) ** 2


def thin_fat(weight_kg: float, height_cm: float, waist_cm: float | None, sex: str) -> bool:
    """BMI under the Asian overweight point but waist at/over the Indian cut-off: start with muscle gain."""
    if waist_cm is None:
        return False
    return bmi(weight_kg, height_cm) < C.ASIAN_BMI_OVERWEIGHT and waist_cm >= C.WAIST_CUTOFF_CM[sex]


Feel = Literal["better", "same", "worse"]
PhaseStatus = Literal["continue", "stepup", "doctor", "doctor_now"]


def phase_next(day: int, feel: Feel, red_flag: bool, previous_feel: Feel | None) -> PhaseStatus:
    """F21 layer 2 exit rules.

    - Red flag (blood in stool, high fever, can't keep fluids down): doctor today.
    - Worse, or no better by day 3: doctor, plan changes paused.
    - Better two days in a row: step up.
    """
    if red_flag:
        return "doctor_now"
    if feel == "worse" or (day >= 3 and feel == "same"):
        return "doctor"
    if feel == "better" and previous_feel == "better":
        return "stepup"
    return "continue"
