#!/usr/bin/env python3
"""Fixture tests for the burn projection maths.

Every case here is a way the naive version gets it wrong. The reset-boundary
case in particular must fail before segmentation exists, otherwise the test
is not testing anything.
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
    row = {
        "ts": ts,
        "five_hour": {"used_percentage": five_pct, "resets_at": five_reset},
    }
    if week_pct is not None:
        row["seven_day"] = {"used_percentage": week_pct, "resets_at": week_reset}
    return row


def run(rows, now):
    """Run burn.py against a fixture history and return its JSON verdict."""
    fh = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    try:
        for r in rows:
            fh.write(json.dumps(r) + "\n")
        fh.close()
        out = subprocess.run(
            [sys.executable, BURN, "--json", "--history", fh.name,
             "--now", str(now), "--no-transcripts"],
            capture_output=True, text=True,
        )
        if out.returncode != 0:
            raise AssertionError(
                "burn.py exited %d\nstdout: %s\nstderr: %s"
                % (out.returncode, out.stdout, out.stderr))
        return json.loads(out.stdout)
    finally:
        os.unlink(fh.name)


class ResetBoundary(unittest.TestCase):
    """The 5h percentage drops to near zero every five hours. A rate computed
    across that boundary reads as a huge negative burn and the projection
    silently inverts."""

    def test_rate_ignores_the_drop(self):
        now = 100 * HOUR
        reset_a = now - 1 * HOUR          # old window, already reset
        reset_b = now + 4 * HOUR          # current window
        rows = [
            sample(now - 3.0 * HOUR, 10, reset_a),
            sample(now - 2.5 * HOUR, 40, reset_a),
            sample(now - 2.0 * HOUR, 70, reset_a),
            # window rolled: percentage collapses and resets_at moves forward
            sample(now - 1.0 * HOUR, 2, reset_b),
            sample(now - 0.5 * HOUR, 12, reset_b),
            sample(now, 22, reset_b),
        ]
        v = run(rows, now)["five_hour"]
        # 12 -> 22 over the last half hour is 20 points an hour.
        self.assertAlmostEqual(v["rate_now"], 20.0, places=3)
        self.assertGreater(v["rate_now"], 0)

    def test_baseline_counts_both_windows(self):
        now = 100 * HOUR
        reset_a, reset_b = now - 1 * HOUR, now + 4 * HOUR
        rows = [
            sample(now - 3.0 * HOUR, 10, reset_a),
            sample(now - 2.0 * HOUR, 70, reset_a),
            sample(now - 1.0 * HOUR, 2, reset_b),
            sample(now, 22, reset_b),
        ]
        v = run(rows, now)["five_hour"]
        # 60 points in the old window plus 20 in the new is 80 over 24h.
        self.assertAlmostEqual(v["rate_baseline"], 80.0 / 24.0, places=3)


    def test_sparse_samples_do_not_read_a_reset_as_negative_burn(self):
        """When nothing landed in the last half hour the rate falls back to the
        last two samples. If those straddle a reset the burn reads negative and
        the projection quietly inverts: falling percentage never breaches."""
        now = 100 * HOUR
        reset_a, reset_b = now - 45 * 60, now + 4 * HOUR
        rows = [
            sample(now - 3.0 * HOUR, 10, reset_a),
            sample(now - 2.0 * HOUR, 85, reset_a),
            sample(now - 40 * 60, 4, reset_b),
        ]
        v = run(rows, now)["five_hour"]
        self.assertFalse(v["rate_now"] is not None and v["rate_now"] < 0,
                         "rate went negative across a reset: %r" % v["rate_now"])
        self.assertTrue(v["thin"])

    def test_rollover_is_not_counted_as_burn(self):
        """A window ending at 2% and the next being first seen at 9% is a
        rollover, not seven points of work. Crossing pairs must not be summed
        even when the percentage rises across the boundary, which is the case
        the drop heuristic alone cannot see."""
        now = 100 * HOUR
        reset_a, reset_b = now - 90 * 60, now + 3 * HOUR
        rows = [
            sample(now - 3.0 * HOUR, 2, reset_a),
            sample(now - 1.0 * HOUR, 9, reset_b),
            sample(now, 15, reset_b),
        ]
        v = run(rows, now)["five_hour"]
        self.assertAlmostEqual(v["rate_baseline"], 6.0 / 24.0, places=3)


class SteadyBurn(unittest.TestCase):
    def test_thirty_minute_rate(self):
        now = 100 * HOUR
        reset = now + 3 * HOUR
        rows = [sample(now - m * 60, 50 - (m / 60.0) * 20, reset)
                for m in range(45, -1, -5)]
        v = run(rows, now)["five_hour"]
        self.assertAlmostEqual(v["rate_now"], 20.0, places=2)
        self.assertFalse(v["thin"])

    def test_projection_and_time_to_100(self):
        now = 100 * HOUR
        reset = now + 3 * HOUR
        rows = [sample(now - m * 60, 50 - (m / 60.0) * 20, reset)
                for m in range(30, -1, -5)]
        v = run(rows, now)["five_hour"]
        # 50% now, 20 points an hour, 3 hours left -> 110% at reset.
        self.assertAlmostEqual(v["projected_at_reset"], 110.0, places=1)
        self.assertTrue(v["will_breach"])
        # 50 points of headroom at 20 an hour is 2.5 hours.
        self.assertAlmostEqual(v["seconds_to_100"], 2.5 * HOUR, delta=60)


class IdleGap(unittest.TestCase):
    """A six hour gap inside a window is real zero-burn time, not missing data.
    Elapsed hours come from the clock, never from the sample count."""

    def test_gap_dilutes_the_baseline(self):
        now = 100 * HOUR
        reset = now + 1 * HOUR
        rows = [
            sample(now - 20 * HOUR, 0, reset),
            sample(now - 14 * HOUR, 24, reset),   # 24 points, then idle
            sample(now - 0.5 * HOUR, 24, reset),
            sample(now, 30, reset),
        ]
        v = run(rows, now)["five_hour"]
        self.assertAlmostEqual(v["rate_baseline"], 30.0 / 24.0, places=3)
        self.assertAlmostEqual(v["rate_now"], 12.0, places=2)


class Momentum(unittest.TestCase):
    def test_accelerating_reads_above_one(self):
        now = 100 * HOUR
        reset = now + 2 * HOUR
        rows = [sample(now - 24 * HOUR + i * HOUR, min(i * 1.0, 40), reset)
                for i in range(24)]
        rows.append(sample(now - 0.5 * HOUR, 40, reset))
        rows.append(sample(now, 60, reset))
        v = run(rows, now)["five_hour"]
        self.assertGreater(v["momentum"], 1.0)

    def test_safe_when_headroom_is_wide(self):
        now = 100 * HOUR
        reset = now + 1 * HOUR
        rows = [
            sample(now - 1 * HOUR, 8, reset),
            sample(now - 0.5 * HOUR, 9, reset),
            sample(now, 10, reset),
        ]
        v = run(rows, now)["five_hour"]
        self.assertFalse(v["will_breach"])
        self.assertIsNone(v["seconds_to_100"])


class ThinAndEmpty(unittest.TestCase):
    def test_thin_when_segment_is_young(self):
        now = 100 * HOUR
        reset = now + 4 * HOUR
        rows = [
            sample(now - 300, 1, reset),
            sample(now, 4, reset),
        ]
        v = run(rows, now)["five_hour"]
        self.assertTrue(v["thin"])

    def test_empty_history_does_not_crash(self):
        v = run([], 100 * HOUR)
        self.assertEqual(v["five_hour"]["baseline_source"], "none")
        self.assertIsNone(v["five_hour"]["used_percentage"])
        self.assertFalse(v["five_hour"]["will_breach"])

    def test_unparseable_lines_are_skipped(self):
        now = 100 * HOUR
        reset = now + 3 * HOUR
        fh = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
        fh.write(json.dumps(sample(now - HOUR, 10, reset)) + "\n")
        fh.write('{"ts": 1, "five_hour": {"used_per\n')      # torn write
        fh.write("\n")
        fh.write(json.dumps(sample(now, 30, reset)) + "\n")
        fh.close()
        try:
            out = subprocess.run(
                [sys.executable, BURN, "--json", "--history", fh.name,
                 "--now", str(now), "--no-transcripts"],
                capture_output=True, text=True)
            self.assertEqual(out.returncode, 0, out.stderr)
            v = json.loads(out.stdout)["five_hour"]
            self.assertEqual(v["used_percentage"], 30)
        finally:
            os.unlink(fh.name)


class Quantisation(unittest.TestCase):
    """The percentages arrive as whole numbers. Over a short span a single
    point of movement is mostly rounding: 94 to 95 in four minutes reads as
    15%/h, and the true rate is anywhere from nothing to twice that. Crying
    breach on that is crying breach on noise, and the throttle would fire on
    a session that was doing almost nothing."""

    def test_one_point_of_movement_is_not_a_breach(self):
        now = 100 * HOUR
        reset = now + 67 * 60
        rows = [
            sample(now - 320, 94, reset),
            sample(now - 257, 94, reset),
            sample(now - 179, 94, reset),
            sample(now - 110, 95, reset),
            sample(now - 45, 95, reset),
        ]
        v = run(rows, now)["five_hour"]
        self.assertTrue(v["thin"])
        self.assertFalse(
            v["will_breach"],
            "declared a breach off a single rounding step: %r%%/h" % v["rate_now"])

    def test_real_movement_still_breaches(self):
        """The guard must not swallow an actual burn. Twenty points in half an
        hour is far outside the rounding, so it must still trip."""
        now = 100 * HOUR
        reset = now + 3 * HOUR
        rows = [sample(now - m * 60, 50 - (m / 60.0) * 20, reset)
                for m in range(30, -1, -5)]
        v = run(rows, now)["five_hour"]
        self.assertTrue(v["will_breach"])


class WeeklyHorizon(unittest.TestCase):
    """A 30 minute burst says nothing about Thursday. The weekly window must
    project on the 24 hour baseline, not on the current burst, or every busy
    half hour cries breach five days out."""

    def test_burst_does_not_trip_the_weekly_window(self):
        now = 100 * HOUR
        five_reset = now + 2 * HOUR
        week_reset = now + 5 * 24 * HOUR
        rows = []
        for i in range(24, 0, -1):
            rows.append(sample(now - i * HOUR, 5, five_reset,
                               20 + (24 - i) * 0.1, week_reset))
        rows.append(sample(now - 0.5 * HOUR, 5, five_reset, 22.4, week_reset))
        rows.append(sample(now, 25, five_reset, 24.0, week_reset))
        v = run(rows, now)
        self.assertFalse(v["seven_day"]["will_breach"])
        self.assertEqual(v["seven_day"]["basis"], "baseline")
        self.assertEqual(v["five_hour"]["basis"], "current")



class CrossSessionJitter(unittest.TestCase):
    """Several live sessions each write their own snapshot of the same server
    side percentage into one shared history. Those snapshots are of different
    ages, so the merged series steps backwards now and then even though the
    real number only climbs inside a window. A backwards step must not be read
    as a reset: doing so truncates the live segment to the two samples either
    side of the dip and turns twenty seconds of noise into a triple digit rate.

    The numbers below are a verbatim slice of the real history from the evening
    the throttle fired: 31 climbing to 35 over nineteen minutes, with one
    session reporting a stale 33 in the middle of it. Every sample carries the
    same reset time, so the definitive signal says plainly that nothing rolled.
    """

    # (seconds after the first sample, percentage), exactly as recorded.
    SLICE = [
        (0, 31), (54, 31), (113, 31), (179, 32), (236, 32), (302, 33),
        (356, 33), (420, 34), (481, 34), (541, 34), (597, 34), (659, 34),
        (715, 35), (806, 35), (905, 35), (955, 35),
        (1132, 33),   # a different session, holding an older snapshot
        (1153, 35),
    ]

    def test_a_stale_snapshot_is_not_a_window_reset(self):
        t0 = 100 * HOUR
        now = t0 + self.SLICE[-1][0]
        reset = now + 8260          # 2h17m of the window left, as recorded
        rows = [sample(t0 + off, pct, reset) for off, pct in self.SLICE]
        v = run(rows, now)["five_hour"]
        # Truth over the whole nineteen minutes is about 12 points per hour.
        self.assertLess(
            v["rate_now"], 60,
            "a 21 second step between two sessions was read as real burn")
        self.assertFalse(
            v["will_breach"],
            "snapshot jitter projected out to a breach and blocked a prompt")


class ResetWithoutTimestamps(unittest.TestCase):
    """The percentage dropping is the only reset signal available when samples
    carry no reset time, so gating it on the timestamps must not disable it.
    Without the split the rate reads as a large negative burn.
    """

    def test_drop_still_splits_when_reset_time_is_missing(self):
        now = 100 * HOUR
        rows = [
            sample(now - 900, 88, None),
            sample(now - 600, 94, None),
            sample(now - 300, 3, None),   # rolled, and nothing here proves it
            sample(now, 9, None),
        ]
        v = run(rows, now)["five_hour"]
        self.assertGreater(
            v["rate_now"], 0,
            "the reset was carried into the rate as negative burn")


class ThinWindow(unittest.TestCase):
    """A reading built on half a minute is real but it is not evidence. It can
    be shown. It must not be the grounds for blocking a prompt.
    """

    def test_thirty_seconds_of_evidence_cannot_block(self):
        now = 100 * HOUR
        reset = now + 4 * HOUR
        rows = [
            sample(now - 30, 40, reset),
            sample(now, 42, reset),
        ]
        v = run(rows, now)["five_hour"]
        self.assertTrue(v["thin"])
        self.assertFalse(
            v["will_breach"],
            "half a minute of evidence was enough to block a prompt")


if __name__ == "__main__":
    unittest.main(verbosity=2)
