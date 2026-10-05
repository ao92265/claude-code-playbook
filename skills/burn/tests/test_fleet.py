#!/usr/bin/env python3
"""Fixture tests for per session attribution.

The account wide percentage cannot say which session spent it, so the split
comes from the transcripts. Every case here is a way a naive split lies about
who is actually burning the quota.
"""
import json
import os
import shutil
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "scripts"))

import fleet  # noqa: E402


def iso(ts):
    return time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime(ts))


def line(ts, sid, cwd="/Users/x/proj", slug="a-session", model="claude-opus-5",
         inp=0, out=0, cread=0, cwrite=0, sidechain=False):
    return json.dumps({
        "timestamp": iso(ts),
        "sessionId": sid,
        "cwd": cwd,
        "slug": slug,
        "gitBranch": "main",
        "isSidechain": sidechain,
        "type": "assistant",
        "message": {
            "model": model,
            "usage": {
                "input_tokens": inp,
                "output_tokens": out,
                "cache_read_input_tokens": cread,
                "cache_creation_input_tokens": cwrite,
                "cache_creation": {"ephemeral_5m_input_tokens": cwrite,
                                   "ephemeral_1h_input_tokens": 0},
            },
        },
    })


class FleetCase(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="burn-fleet-")
        self.now = 1_800_000_000

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def write(self, project, sid, lines, mtime=None):
        d = os.path.join(self.root, project)
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, sid + ".jsonl")
        with open(path, "a") as fh:
            for ln in lines:
                fh.write(ln + "\n")
        stamp = mtime if mtime is not None else self.now
        os.utime(path, (stamp, stamp))
        return path

    def build(self, rate=None):
        return fleet.build(self.now, root=self.root, rate=rate)


class Splitting(FleetCase):
    def test_the_heavier_session_ranks_first(self):
        self.write("p1", "aaa", [line(self.now - 300, "aaa", out=10_000)])
        self.write("p2", "bbb", [line(self.now - 300, "bbb", out=1_000)])
        out = self.build()
        self.assertEqual([s["session_id"] for s in out["sessions"]], ["aaa", "bbb"])
        self.assertAlmostEqual(sum(s["share"] for s in out["sessions"]), 1.0, places=6)

    def test_a_cache_read_heavy_session_does_not_outrank_a_generating_one(self):
        # Flat token counting puts the cache reader 30x ahead here. Priced
        # against what a cache read actually costs, it is the smaller of the
        # two, which is the honest answer.
        self.write("p1", "cache", [line(self.now - 300, "cache", cread=1_000_000, out=1_000)])
        self.write("p2", "work", [line(self.now - 300, "work", out=30_000)])
        out = self.build()
        self.assertEqual(out["sessions"][0]["session_id"], "work")

    def test_output_counts_for_more_than_input(self):
        self.write("p1", "in", [line(self.now - 300, "in", inp=100_000)])
        self.write("p2", "out", [line(self.now - 300, "out", out=100_000)])
        out = self.build()
        self.assertEqual(out["sessions"][0]["session_id"], "out")

    def test_the_account_rate_is_split_by_share(self):
        self.write("p1", "aaa", [line(self.now - 300, "aaa", out=3_000)])
        self.write("p2", "bbb", [line(self.now - 300, "bbb", out=1_000)])
        out = self.build(rate=8.0)
        by = dict((s["session_id"], s["pct_per_h"]) for s in out["sessions"])
        self.assertAlmostEqual(by["aaa"], 6.0, places=6)
        self.assertAlmostEqual(by["bbb"], 2.0, places=6)


class WindowAndLiveness(FleetCase):
    def test_work_older_than_the_window_is_not_counted(self):
        self.write("p1", "old", [line(self.now - 4 * 3600, "old", out=50_000)])
        self.write("p2", "now", [line(self.now - 300, "now", out=1_000)])
        out = self.build()
        self.assertEqual([s["session_id"] for s in out["sessions"]], ["now"])

    def test_a_session_idle_this_window_is_absent_not_zero(self):
        # An idle session must not sit in the list claiming 0%, because six of
        # those bury the one session that is actually burning.
        self.write("p1", "idle", [line(self.now - 7200, "idle", out=1_000)],
                   mtime=self.now - 7200)
        self.write("p2", "busy", [line(self.now - 60, "busy", out=1_000)])
        out = self.build()
        self.assertEqual([s["session_id"] for s in out["sessions"]], ["busy"])

    def test_no_transcripts_is_an_empty_fleet_not_a_crash(self):
        out = self.build(rate=5.0)
        self.assertEqual(out["sessions"], [])
        self.assertEqual(out["total_weighted"], 0)


class Attribution(FleetCase):
    def test_subagent_work_counts_toward_the_session_that_spawned_it(self):
        self.write("p1", "parent", [
            line(self.now - 300, "parent", out=1_000),
            line(self.now - 200, "parent", out=9_000, sidechain=True),
        ])
        out = self.build()
        s = out["sessions"][0]
        self.assertEqual(s["session_id"], "parent")
        self.assertGreater(s["subagent_share"], 0.8)

    def test_one_session_spread_over_several_files_is_one_row(self):
        """Subagents get their own transcript file carrying the parent's
        session id. Counted per file, one session appears three times and its
        real spend is split across rows that each look small."""
        self.write("p1", "parent", [line(self.now - 300, "parent", slug="the-work",
                                         out=1_000)])
        self.write("p1", "agent-review", [line(self.now - 250, "parent", out=6_000,
                                               sidechain=True)])
        self.write("p1", "agent-tests", [line(self.now - 200, "parent", out=3_000,
                                              sidechain=True)])
        out = self.build()
        self.assertEqual(len(out["sessions"]), 1)
        s = out["sessions"][0]
        self.assertEqual(s["slug"], "the-work")
        self.assertAlmostEqual(s["subagent_share"], 0.9, places=6)

    def test_the_biggest_file_of_his_own_work_names_the_session(self):
        """Merging compares each file against the running total, so once two
        files are folded in, a later and genuinely larger one can never take
        the label and the session gets reported under a subagent's name."""
        self.write("p1", "a-small", [line(self.now - 300, "s", slug="small", out=1_000)])
        self.write("p1", "b-small", [line(self.now - 280, "s", slug="small", out=1_000)])
        # Bigger than either file on its own, smaller than the two combined,
        # which is exactly where a comparison against the running total hides
        # the real owner.
        self.write("p1", "c-big", [line(self.now - 260, "s", slug="the-real-one",
                                        cwd="/Users/x/real", out=1_500)])
        s = self.build()["sessions"][0]
        self.assertEqual(s["slug"], "the-real-one")

    def test_a_session_is_labelled_by_its_slug_and_project(self):
        self.write("p1", "aaa", [line(self.now - 300, "aaa", slug="fix-the-hud",
                                      cwd="/Users/x/Repos/thing", out=1_000)])
        s = self.build()["sessions"][0]
        self.assertEqual(s["slug"], "fix-the-hud")
        self.assertEqual(s["cwd"], "/Users/x/Repos/thing")
        self.assertEqual(s["model"], "claude-opus-5")

    def test_the_current_session_is_marked(self):
        self.write("p1", "mine", [line(self.now - 300, "mine", out=1_000)])
        self.write("p2", "other", [line(self.now - 300, "other", out=2_000)])
        out = fleet.build(self.now, root=self.root, session_id="mine")
        by = dict((s["session_id"], s["is_current"]) for s in out["sessions"])
        self.assertTrue(by["mine"])
        self.assertFalse(by["other"])

    def test_a_torn_line_does_not_lose_the_rest_of_the_file(self):
        path = self.write("p1", "aaa", [line(self.now - 300, "aaa", out=1_000)])
        with open(path, "a") as fh:
            fh.write('{"timestamp":"2026-0')          # a half written append
        self.write("p1", "aaa", [line(self.now - 100, "aaa", out=1_000)])
        out = self.build()
        self.assertEqual(len(out["sessions"]), 1)
        self.assertGreater(out["sessions"][0]["weighted"], 0)


class Reading(FleetCase):
    def test_a_freshly_reset_window_shows_shares_without_a_fake_rate(self):
        """The account rate is ~0 for the first minutes of a new window, and a
        column of 0.0%/h next to real shares reads as "nobody is doing
        anything" when six sessions are hard at work."""
        self.write("p1", "aaa", [line(self.now - 300, "aaa", out=3_000)])
        text = fleet.human(fleet.build(self.now, root=self.root, rate=0.0))
        self.assertNotIn("%/h", text)
        self.assertIn("100%", text)


class SummerTime(FleetCase):
    """Transcript timestamps are UTC. Reading them through local time shifts
    every session by the daylight saving offset, which silently empties the
    fleet for half the year: fixtures dated in January never notice.
    """

    def setUp(self):
        FleetCase.setUp(self)
        self.now = 1_782_000_000          # inside British Summer Time

    def test_a_summer_timestamp_is_still_inside_the_window(self):
        self.write("p1", "aaa", [line(self.now - 300, "aaa", out=1_000)])
        self.assertEqual(len(self.build()["sessions"]), 1)


class ThroughBurn(FleetCase):
    """/burn is where anyone actually reads this, so the wiring is the thing
    worth testing: the split must add back up to the account rate."""

    BURN = os.path.join(HERE, "..", "scripts", "burn.py")

    def history(self, pct_from, pct_to, reset_in=3 * 3600):
        rows = []
        for m in range(60, -1, -5):
            frac = (60 - m) / 60.0
            rows.append({"ts": self.now - m * 60,
                         "five_hour": {"used_percentage": pct_from + (pct_to - pct_from) * frac,
                                       "resets_at": self.now + reset_in}})
        path = os.path.join(self.root, "history.jsonl")
        with open(path, "w") as fh:
            fh.write("\n".join(json.dumps(r) for r in rows) + "\n")
        return path

    def burn(self, *extra):
        import subprocess
        hist = self.history(20, 26)
        out = subprocess.run(
            [sys.executable, self.BURN, "--json", "--history", hist,
             "--now", str(self.now), "--no-transcripts",
             "--projects", self.root] + list(extra),
            capture_output=True, text=True)
        if out.returncode != 0:
            raise AssertionError(out.stderr)
        return json.loads(out.stdout)

    def test_the_split_adds_back_up_to_the_account_rate(self):
        self.write("p1", "aaa", [line(self.now - 300, "aaa", out=3_000)])
        self.write("p2", "bbb", [line(self.now - 300, "bbb", out=1_000)])
        v = self.burn("--fleet")
        rate = v["five_hour"]["rate_now"]
        share = sum(s["pct_per_h"] for s in v["fleet"]["sessions"])
        self.assertAlmostEqual(share, rate, places=6)
        self.assertEqual(len(v["fleet"]["sessions"]), 2)

    def test_the_fleet_is_not_computed_unless_asked(self):
        """The throttle hook runs this on every prompt. Walking the transcript
        tree on every prompt is how a hook becomes something he turns off."""
        self.write("p1", "aaa", [line(self.now - 300, "aaa", out=3_000)])
        self.assertIsNone(self.burn().get("fleet"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
