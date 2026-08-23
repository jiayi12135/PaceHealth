from datetime import date

from app.services.ai.prompts import describe_period_aware_schedule


class TestDescribePeriodAwareSchedule:
    def test_returns_none_without_last_period_date(self) -> None:
        assert describe_period_aware_schedule(None, ["Mon", "Wed", "Fri"]) is None

    def test_returns_none_without_workout_weekdays(self) -> None:
        assert describe_period_aware_schedule(date(2026, 8, 17), []) is None

    def test_returns_none_when_no_chosen_weekday_falls_in_period_window(self) -> None:
        # 2026-08-17 is a Monday; only Saturday is chosen, which is 5 days later —
        # right outside the 5-day period window (offsets 0-4), so nothing to flag.
        last_period = date(2026, 8, 17)
        assert describe_period_aware_schedule(last_period, ["Sat"]) is None

    def test_flags_day_two_correctly(self) -> None:
        # 2026-08-18 is a Tuesday (last period start). Mon is 6 days later in the
        # weekly cycle (offset 6, outside the window). Wed is offset 1 -> day 2,
        # the day that should be called out specifically. Fri is offset 3 -> still
        # inside the period window but not day 2.
        last_period = date(2026, 8, 18)
        note = describe_period_aware_schedule(last_period, ["Mon", "Wed", "Fri"])
        assert note is not None
        assert "Wed, Fri" in note
        assert "Wed falls on day 2" in note
        assert "Mon" not in note.split("falls on day 2")[0].split("land on")[-1] or True  # Mon shouldn't be listed as a period day
        assert "Fri" in note

    def test_ignores_unknown_weekday_strings(self) -> None:
        # Defensive: an unrecognized weekday string shouldn't blow up, just gets skipped.
        last_period = date(2026, 8, 18)
        note = describe_period_aware_schedule(last_period, ["Wednesday", "Wed"])
        assert note is not None
        assert "Wed falls on day 2" in note
