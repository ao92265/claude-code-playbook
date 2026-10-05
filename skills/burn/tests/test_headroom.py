#!/usr/bin/env python3
"""Fixture tests for the other half of the ladder: when you can afford more.

The throttle only ever stepped down. These cases pin the reverse reading, and
in particular the two ways "you have loads left" is a lie: the weekly window
being the one that is tight, and a reading built on three minutes of history.
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
BURN = os.path.join(HERE, "..", "scripts", "burn.py")

HOUR = 3600


def sample(ts, five_pct, five_reset, week_pct=None, week_reset=None):
    row = {"ts": ts, "five_hour": {"used_percentage": five_pct, "resets_at": five_reset}}
    if week_pct is not None:
        row["seven_day"] = {"used_percentage": week_pct, "resets_at": week_reset}
    return row


def run(rows, now):
    fh = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    try:
        for r in rows:
            fh.write(json.dumps(r) + "\n")
        fh.close()
        out = subprocess.run(
            [sys.executable, BURN, "--json", "--history", fh.name,
             "--now", str(now), "--no-transcripts"],
            capture_output=True, text=True)
        if out.returncode != 0:
            raise AssertionError("burn.py exited %d\n%s" % (out.returncode, out.stderr))
        return json.loads(out.stdout)
    finally:
        os.unlink(fh.name)


NOW = 1_800_000_000


def ramp(start, end, minutes=60, step=5, reset_in=4 * HOUR,
         week_start=None, week_end=None, week_reset_in=5 * 86400):
    """Samples ramping from start% to end% over the last `minutes`."""
    rows = []
    for m in range(minutes, -1, -step):
        frac = (minutes - m) / float(minutes)
        wk = None
        if week_start is not None:
            wk = week_start + (week_end - week_start) * frac
        rows.append(sample(NOW - m * 60, start + (end - start) * frac,
                           NOW + reset_in, wk,
                           NOW + week_reset_in if wk is not None else None))
    return rows


class Slack(unittest.TestCase):
    def test_a_quiet_window_reports_how_much_harder_you_could_burn(self):
        # 20% used, 4 hours left, burning 4%/h. Landing at 100% would take
        # 20%/h, so there is five times the current burn spare.
        v = run(ramp(16, 20, week_start=10, week_end=11), NOW)
        five = v["five_hour"]
        self.assertAlmostEqual(five["ceiling_rate"], 20.0, places=1)
        self.assertGreater(five["slack"], 4.0)
        self.assertTrue(v["can_scale_up"])

    def test_an_idle_window_is_scalable_and_never_divides_by_zero(self):
        v = run(ramp(20, 20, week_start=10, week_end=10), NOW)
        self.assertIsNotNone(v["five_hour"]["slack"])
        self.assertTrue(v["can_scale_up"])

    def test_a_projected_breach_is_never_scalable(self):
        v = run(ramp(60, 92, week_start=10, week_end=11), NOW)
        self.assertTrue(v["five_hour"]["will_breach"])
        self.assertFalse(v["can_scale_up"])

    def test_a_tight_week_blocks_scaling_up_on_a_clear_five_hour(self):
        # The five hour window resets in four hours and is nearly empty. The
        # week is the one with nothing left, and the week is what governs.
        v = run(ramp(2, 4, week_start=90, week_end=96), NOW)
        self.assertFalse(v["five_hour"]["will_breach"])
        self.assertLess(v["seven_day"]["slack"], 2.0)
        self.assertFalse(v["can_scale_up"])

    def test_three_minutes_of_history_is_too_thin_to_promise_headroom(self):
        rows = [sample(NOW - 180, 20, NOW + 4 * HOUR, 10, NOW + 5 * 86400),
                sample(NOW, 20, NOW + 4 * HOUR, 10, NOW + 5 * 86400)]
        v = run(rows, NOW)
        self.assertTrue(v["five_hour"]["thin"])
        self.assertFalse(v["can_scale_up"])

    def test_a_window_with_no_history_does_not_veto_the_one_that_has_it(self):
        v = run(ramp(16, 20), NOW)               # five hour only, no weekly
        self.assertIsNone(v["seven_day"]["slack"])
        self.assertTrue(v["can_scale_up"])

    def test_an_hour_old_reading_cannot_promise_headroom(self):
        """Samples only land while a statusline is rendering, so a gap is
        normal. Telling him to go back up to the big model on percentages from
        an hour and a half ago is wrong in the one direction that costs a
        breach."""
        rows = [dict(r, ts=r["ts"] - 91 * 60) for r in ramp(16, 20)]
        v = run(rows, NOW)
        self.assertFalse(v["can_scale_up"])
        self.assertGreater(v["five_hour"]["age_s"], 5400)

    def test_no_history_at_all_cannot_promise_headroom(self):
        v = run([], NOW)
        self.assertFalse(v["can_scale_up"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
