from datetime import date, timedelta

import pytest

from engine.maintenance import IntakeDay, adaptive_maintenance
from engine.trend import Rate, WeighIn, on_track, weekly_rate

D0 = date(2026, 10, 1)


def linear(days: int, start: float, per_day: float) -> list[WeighIn]:
    return [WeighIn(D0 + timedelta(days=i), start + per_day * i) for i in range(days)]


def test_under_ten_days_is_not_enough_data():
    r = weekly_rate(linear(9, 80, -0.1))
    assert not r.enough_data
    assert r.data_days == 9
    assert on_track("fat_loss", r) == "not_enough_data"


def test_rate_from_linear_loss():
    r = weekly_rate(linear(14, 80, -0.1))
    assert r.kg_per_week == pytest.approx(-0.7)
    # mean weight = 80 - 0.1 * 6.5 = 79.35
    assert r.pct_per_week == pytest.approx(-0.7 / 79.35 * 100, abs=1e-3)
    assert on_track("fat_loss", r) == "on_pace"


def test_excluded_days_do_not_move_the_trend():
    data = linear(14, 80, -0.1)
    data.append(WeighIn(D0 + timedelta(days=7), 85.0, excluded=True))  # unwell day, water spike
    assert weekly_rate(data).kg_per_week == pytest.approx(-0.7)


def test_same_day_last_weigh_in_wins():
    data = linear(14, 80, -0.1) + [WeighIn(D0 + timedelta(days=13), 78.7)]
    assert weekly_rate(data).data_days == 14


@pytest.mark.parametrize(
    "goal,pct,verdict",
    [
        ("fat_loss", -0.3, "too_slow"),
        ("fat_loss", -0.7, "on_pace"),
        ("fat_loss", -1.4, "too_fast"),
        ("fat_loss", 0.2, "wrong_direction"),
        ("muscle_gain", 0.2, "on_pace"),
        ("muscle_gain", 0.8, "too_fast"),
        ("muscle_gain", -0.2, "wrong_direction"),
    ],
)
def test_on_track_verdicts(goal, pct, verdict):
    assert on_track(goal, Rate(True, 14, kg_per_week=0, pct_per_week=pct)) == verdict


def test_maintenance_from_intake_and_trend():
    # eating 2000/day while losing 0.1 kg/day -> 2000 + 0.1 * 7700 = 2770
    intake = [IntakeDay(D0 + timedelta(days=i), 2000, True) for i in range(21)]
    est = adaptive_maintenance(intake, linear(21, 80, -0.1))
    assert est.kcal == 2770
    assert est.complete_days == 21
    # full coverage x 20/28 span
    assert est.confidence == 0.71


def test_incomplete_log_days_are_ignored():
    intake = [IntakeDay(D0 + timedelta(days=i), 2000, True) for i in range(21)]
    intake += [IntakeDay(D0 + timedelta(days=i), 800, False) for i in range(21)]  # half-logged days
    assert adaptive_maintenance(intake, linear(21, 80, -0.1)).kcal == 2770


def test_maintenance_needs_ten_complete_days():
    intake = [IntakeDay(D0 + timedelta(days=i), 2000, i < 5) for i in range(21)]
    est = adaptive_maintenance(intake, linear(21, 80, -0.1))
    assert est.kcal is None
    assert est.reason == "not_enough_complete_logs"
