import pytest

from engine.food import KcalRange, allowed, apply_oil, raw_cooked_guard
from engine.health import phase_next, thin_fat
from engine.movement import step_target, walking_kcal
from engine.volume import SetLog, volume_band, weekly_sets_by_region

# Volume ----------------------------------------------------------------------

CONTRIB = {
    "incline_db_press_30": {"pec_clavicular": 1.0, "pec_sternal": 0.5, "delt_front": 0.5},
    "pec_deck": {"pec_sternal": 1.0, "pec_clavicular": 0.5},
}


def test_only_hard_sets_count():
    sets = [SetLog("incline_db_press_30", 1), SetLog("incline_db_press_30", 3)]  # 3 = "3+", not hard
    assert weekly_sets_by_region(sets, CONTRIB)["pec_clavicular"] == 1.0


def test_contribution_weights_add_up_per_region():
    sets = [SetLog("incline_db_press_30", 2)] * 4 + [SetLog("pec_deck", 0)] * 3
    v = weekly_sets_by_region(sets, CONTRIB)
    assert v == {"pec_clavicular": 5.5, "pec_sternal": 5.0, "delt_front": 2.0}


def test_unknown_exercise_is_skipped():
    assert weekly_sets_by_region([SetLog("mystery", 0)], CONTRIB) == {}


@pytest.mark.parametrize("sets,band", [(6, "below"), (12, "in"), (20, "in"), (21, "above")])
def test_volume_band(sets, band):
    assert volume_band(sets) == band


# Movement --------------------------------------------------------------------


def test_walking_matches_movement_mockup():
    # Mockup: 70 kg, 2 x 20 min at 5.5 km/h, 5% incline, "about 245 kcal"
    w = walking_kcal(70, 5.5, 5, 40)
    assert w.net_kcal == 244
    assert w.in_valid_range


def test_incline_roughly_doubles_flat_walking():
    flat = walking_kcal(70, 5.5, 0, 20).net_kcal
    incline = walking_kcal(70, 5.5, 5, 20).net_kcal
    assert incline / flat == pytest.approx(1.9, abs=0.05)


def test_running_speed_is_outside_walking_equation():
    assert not walking_kcal(70, 8, 0, 20).in_valid_range


@pytest.mark.parametrize(
    "baseline,weeks,age,target",
    [(3400, 1, 30, 4400), (3400, 10, 30, 10000), (3400, 10, 65, 8000), (12000, 3, 30, 12000)],
)
def test_step_ramp(baseline, weeks, age, target):
    assert step_target(baseline, weeks, age) == target


# Food ------------------------------------------------------------------------

TIKKA = KcalRange(510, 1249, 2033)


def test_oil_extra_adds_one_tbsp():
    r = apply_oil(TIKKA, "extra")
    assert (r.kcal, r.oil_adjust_kcal, r.clamped) == (1369, 120, False)


def test_oil_less_removes_half_tbsp():
    assert apply_oil(TIKKA, "less").kcal == 1189


def test_oil_never_leaves_measured_range():
    r = apply_oil(KcalRange(300, 350, 400), "extra")
    assert (r.kcal, r.oil_adjust_kcal, r.clamped) == (400, 50, True)


@pytest.mark.parametrize(
    "kind,state,grams,flag",
    [("rice", "cooked", 80, "small_cooked_rice"), ("rice", "raw", 80, None), ("rice", "cooked", 150, None)],
)
def test_raw_cooked_guard(kind, state, grams, flag):
    assert raw_cooked_guard(kind, state, grams) == flag


VEG_NO_DAIRY = {
    "diet_type": "veg", "contains_lactose": "no", "contains_gluten": "check",
    "contains_nuts": "no", "contains_egg": "no", "contains_fish": "no", "contains_soy": "no",
}


def test_lactose_limit_blocks_dairy():
    assert not allowed({**VEG_NO_DAIRY, "contains_lactose": "yes"}, "veg", ["lactose"])


def test_draft_check_tag_blocks_like_yes():
    assert not allowed(VEG_NO_DAIRY, "veg", ["gluten"])
    assert allowed(VEG_NO_DAIRY, "veg", ["lactose"])


def test_diet_type_filter():
    assert not allowed({**VEG_NO_DAIRY, "diet_type": "nonveg"}, "veg", [])
    assert allowed({**VEG_NO_DAIRY, "diet_type": "egg"}, "egg", [])


def test_jain_needs_explicit_ok():
    assert not allowed(VEG_NO_DAIRY, "jain", [])
    assert allowed({**VEG_NO_DAIRY, "jain_ok": "yes"}, "jain", [])


# Health ----------------------------------------------------------------------


def test_thin_fat_flag():
    # 60 kg / 175 cm -> BMI 19.6, waist over 90 cm (male)
    assert thin_fat(60, 175, 92, "male")
    assert not thin_fat(60, 175, 85, "male")
    assert not thin_fat(60, 175, None, "male")


@pytest.mark.parametrize(
    "day,feel,red,prev,status",
    [
        (1, "same", True, None, "doctor_now"),
        (2, "worse", False, "same", "doctor"),
        (3, "same", False, "same", "doctor"),
        (2, "same", False, "same", "continue"),
        (2, "better", False, "same", "continue"),
        (3, "better", False, "better", "stepup"),
    ],
)
def test_unwell_phase_rules(day, feel, red, prev, status):
    assert phase_next(day, feel, red, prev) == status
