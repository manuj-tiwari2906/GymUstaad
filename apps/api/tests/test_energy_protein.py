import pytest

from engine.energy import bmr_mifflin, goal_target, initial_maintenance
from engine.protein import protein_target


def test_bmr_male():
    # 10*70 + 6.25*175 - 5*30 + 5
    assert bmr_mifflin(70, 175, 30, "male") == pytest.approx(1648.75)


def test_bmr_female():
    # 10*60 + 6.25*160 - 5*25 - 161
    assert bmr_mifflin(60, 160, 25, "female") == pytest.approx(1314)


def test_initial_maintenance_desk():
    assert initial_maintenance(70, 175, 30, "male", "desk") == pytest.approx(1648.75 * 1.4)


def test_fat_loss_default_rate():
    # deficit = 80 kg * 0.7% * 7700 / 7 = 616
    t = goal_target("fat_loss", maintenance_kcal=2500, weight_kg=80, bmr=1700, sex="male")
    assert t.kcal == 1884
    assert t.rate_pct_per_week == -0.7
    assert not t.floored


def test_fat_loss_rate_is_clamped_to_band():
    t = goal_target("fat_loss", 2500, 80, 1500, "male", loss_rate_pct=2.0)
    # clamped to 1.0%: deficit = 80 * 0.01 * 7700 / 7 = 880
    assert t.kcal == 1620
    assert t.rate_pct_per_week == -1.0


def test_fat_loss_never_below_floor_or_bmr():
    # 1600 - 660 = 940, below max(1200 floor, 1314 BMR) -> 1314
    t = goal_target("fat_loss", 1600, 60, bmr=1314, sex="female", loss_rate_pct=1.0)
    assert t.kcal == 1314
    assert t.floored
    # (1600 - 1314) * 7 / 7700 / 60 * 100
    assert t.rate_pct_per_week == -0.43


def test_muscle_gain_surplus():
    assert goal_target("muscle_gain", 2500, 70, 1650, "male").kcal == 2750


def test_protein_gain_bodyweight():
    p = protein_target("muscle_gain", 70)
    assert (p.grams, p.low_g, p.high_g, p.basis) == (112, 112, 154, "bodyweight")


def test_protein_cut_uses_lean_mass_when_known():
    # LBM = 80 * 0.8 = 64 kg; 2.3-3.1 g/kg LBM
    p = protein_target("fat_loss", 80, body_fat_pct=20)
    assert (p.grams, p.high_g, p.basis) == (147, 198, "lean_mass")


def test_protein_cut_without_body_fat_falls_back_to_bodyweight():
    assert protein_target("fat_loss", 80).basis == "bodyweight"
