#!/usr/bin/env python3
"""Behaviour tests for the throttle hook.

Every case here is a way this feature becomes hated rather than useful:
blocking twice, blocking forever, losing the typed prompt, or leaving him
downgraded after the window it was protecting has already reset.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
THROTTLE = os.path.join(HERE, "..", "scripts", "throttle.py")
HOUR = 3600
PROMPT = "refactor the auth middleware and add tests"


class ThrottleBase(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="burn-throttle-")
        os.makedirs(os.path.join(self.dir, "skills"), exist_ok=True)
        os.symlink(os.path.join(HERE, ".."), os.path.join(self.dir, "skills", "burn"))
        self.settings = os.path.join(self.dir, "settings.json")
        self.write_settings({"effortLevel": "high", "permissions": {"allow": []}})

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    # -- helpers ----------------------------------------------------------
    def write_settings(self, data):
        with open(self.settings, "w") as fh:
            json.dump(data, fh)

    def settings_now(self):
        with open(self.settings) as fh:
            return json.load(fh)

    def state(self):
        p = os.path.join(self.dir, "burn-state.json")
        if not os.path.exists(p):
            return None
        with open(p) as fh:
            return json.load(fh)

    def history(self, start, end, now, reset_in=3 * HOUR, reset_at=None):
        """One hour of samples ramping from start% to end%."""
        import time as _t
        now = now or int(_t.time())
        reset = reset_at if reset_at is not None else now + reset_in
        rows = []
        for m in range(60, -1, -5):
            frac = (60 - m) / 60.0
            rows.append({"ts": now - m * 60,
                         "five_hour": {"used_percentage": start + (end - start) * frac,
                                       "resets_at": reset}})
        with open(os.path.join(self.dir, "usage-history.jsonl"), "w") as fh:
            fh.write("\n".join(json.dumps(r) for r in rows) + "\n")
        return reset

    def run_hook(self, prompt=PROMPT):
        env = dict(os.environ, CLAUDE_CONFIG_DIR=self.dir)
        env.pop("BURN_THROTTLE_OFF", None)
        return subprocess.run(
            [sys.executable, THROTTLE], input=json.dumps({"prompt": prompt}),
            capture_output=True, text=True, env=env)

    def age_rung(self, seconds):
        p = os.path.join(self.dir, "burn-state.json")
        with open(p) as fh:
            d = json.load(fh)
        for me in (d.get("sessions") or {}).values():
            if "rung_at" in me:
                me["rung_at"] -= seconds
        with open(p, "w") as fh:
            json.dump(d, fh)

    def rung(self, sid="default"):
        st = self.state() or {}
        return ((st.get("sessions") or {}).get(sid) or {}).get("rung")

    def burning(self, now=None):
        return self.history(0, 32, now)      # 32 points in an hour, 3h to reset

    def quiet(self, now=None):
        return self.history(8, 8.3, now)


class ThrottleCase(ThrottleBase):
    """Stepping down."""

    def test_first_breach_blocks_on_effort(self):
        self.burning(None)
        r = self.run_hook()
        self.assertEqual(r.returncode, 2)
        self.assertIn("/effort low", r.stderr)
        self.assertEqual(self.settings_now()["effortLevel"], "low")

    def test_typed_prompt_is_never_lost(self):
        """Exit code 2 erases the prompt. If it is not handed back, a long
        message he just typed is gone, and once is enough to make him rip
        this out."""
        self.burning(None)
        r = self.run_hook()
        self.assertIn(PROMPT, r.stderr)
        saved = os.path.join(self.dir, "burn-last-prompt.txt")
        self.assertTrue(os.path.exists(saved))
        with open(saved) as fh:
            self.assertEqual(fh.read(), PROMPT)

    def test_second_prompt_is_not_blocked_again(self):
        """A hook that blocks every prompt makes Claude Code unusable, which is
        worse than any limit it was protecting."""
        self.burning(None)
        self.assertEqual(self.run_hook().returncode, 2)
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertEqual(self.run_hook().returncode, 0)

    def test_model_rung_waits_for_the_cooldown(self):
        self.burning(None)
        self.run_hook()
        self.assertEqual(self.run_hook().returncode, 0)   # too soon
        self.age_rung(3600)
        r = self.run_hook()
        self.assertEqual(r.returncode, 2)
        self.assertIn("/model sonnet", r.stderr)
        self.assertEqual(self.settings_now()["model"], "sonnet")

    def test_ladder_stops_after_two_rungs(self):
        self.burning(None)
        self.run_hook()
        self.age_rung(3600)
        self.run_hook()
        self.age_rung(3600)
        self.assertEqual(self.run_hook().returncode, 0)

    def test_clearing_projection_restores_settings(self):
        self.burning(None)
        self.run_hook()
        self.age_rung(3600)
        self.run_hook()
        self.quiet(None)
        self.assertEqual(self.run_hook().returncode, 0)
        s = self.settings_now()
        self.assertEqual(s["effortLevel"], "high")
        self.assertNotIn("model", s)      # there was no model key to begin with
        self.assertIsNone(self.state())

    def test_window_reset_restores_even_while_still_busy(self):
        """The dangerous case: still burning hard, but into a NEW window. The
        old downgrade must not ride along, or one busy hour leaves him on
        Sonnet for the rest of the day."""
        import time as _t
        now = int(_t.time())
        self.history(0, 32, now, reset_at=now + 3 * HOUR)
        self.assertEqual(self.run_hook().returncode, 2)
        self.assertEqual(self.settings_now()["effortLevel"], "low")
        # window rolled: new resets_at, percentage restarted, still climbing
        self.history(0, 32, now, reset_at=now + 4 * HOUR)
        r = self.run_hook()
        self.assertEqual(r.returncode, 2)
        self.assertEqual(self.rung(), 1)              # back to the first rung
        self.assertEqual(self.state()["original"]["effortLevel"], "high")

    def test_off_switch_holds(self):
        self.burning(None)
        open(os.path.join(self.dir, "burn-off"), "w").close()
        r = self.run_hook()
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stderr, "")
        self.assertEqual(self.settings_now()["effortLevel"], "high")

    def test_quiet_usage_never_blocks(self):
        self.quiet(None)
        r = self.run_hook()
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stderr, "")

    def test_no_history_never_blocks(self):
        r = self.run_hook()
        self.assertEqual(r.returncode, 0)

    def test_unreadable_settings_does_not_wedge_the_prompt(self):
        """If settings.json cannot be parsed the throttle must still let him
        work. A broken config is not a reason to lock him out of his editor."""
        self.burning(None)
        with open(self.settings, "w") as fh:
            fh.write("{ this is not json")
        r = self.run_hook()
        self.assertIn(r.returncode, (0, 2))
        self.assertNotIn("Traceback", r.stderr)


class NamesTheBurner(ThrottleBase):
    """A block that says "you are about to run out" and not "this session is
    doing it" leaves him to go and look, which is the step he will not take."""

    def transcripts(self, *sessions):
        import time as _t
        root = os.path.join(self.dir, "projects", "p1")
        os.makedirs(root, exist_ok=True)
        for sid, slug, out in sessions:
            row = {
                "timestamp": _t.strftime("%Y-%m-%dT%H:%M:%S.000Z", _t.gmtime()),
                "sessionId": sid, "slug": slug, "cwd": "/Users/x/" + slug,
                "type": "assistant",
                "message": {"model": "claude-opus-5",
                            "usage": {"input_tokens": 1, "output_tokens": out}},
            }
            with open(os.path.join(root, sid + ".jsonl"), "w") as fh:
                fh.write(json.dumps(row) + "\n")

    def run_hook(self, prompt=PROMPT, sid=None):
        env = dict(os.environ, CLAUDE_CONFIG_DIR=self.dir)
        env.pop("BURN_THROTTLE_OFF", None)
        payload = {"prompt": prompt}
        if sid:
            payload["session_id"] = sid
        return subprocess.run(
            [sys.executable, THROTTLE], input=json.dumps(payload),
            capture_output=True, text=True, env=env)

    def test_the_block_names_the_session_doing_the_burning(self):
        self.burning(None)
        self.transcripts(("heavy", "the-big-one", 90_000), ("light", "tiny", 1_000))
        r = self.run_hook(sid="light")
        self.assertEqual(r.returncode, 2)
        self.assertIn("the-big-one", r.stderr)

    def test_it_says_when_the_one_burning_is_the_session_being_blocked(self):
        self.burning(None)
        self.transcripts(("heavy", "the-big-one", 90_000), ("light", "tiny", 1_000))
        r = self.run_hook(sid="heavy")
        self.assertIn("this session", r.stderr)

    def test_no_transcripts_means_no_line_about_them(self):
        self.burning(None)
        r = self.run_hook(sid="whoever")
        self.assertEqual(r.returncode, 2)
        self.assertNotIn("Most of it", r.stderr)


class RestoreFailure(ThrottleBase):
    """The state file is the ONLY record of what he was on before the throttle
    touched it. Deleting it after a restore that did not actually happen pins
    him to the small model with nothing left to explain why."""

    def test_a_failed_restore_keeps_the_record_of_his_original_settings(self):
        self.burning(None)
        self.assertEqual(self.run_hook().returncode, 2)
        self.assertEqual(self.state()["original"]["effortLevel"], "high")
        with open(self.settings, "w") as fh:
            fh.write("{ not json at all")     # a writable dir still renames fine
        self.quiet(None)
        self.assertEqual(self.run_hook().returncode, 0)
        st = self.state()
        self.assertIsNotNone(st, "state deleted despite the restore failing")
        self.assertEqual(st["original"]["effortLevel"], "high")

    def test_the_record_survives_a_window_reset_it_could_not_restore_for(self):
        import time as _t
        now = int(_t.time())
        self.history(0, 32, now, reset_at=now + 3 * HOUR)
        self.assertEqual(self.run_hook().returncode, 2)
        with open(self.settings, "w") as fh:
            fh.write("{ not json at all")
        self.history(0, 32, now, reset_at=now + 4 * HOUR)
        self.run_hook()
        st = self.state()
        self.assertIsNotNone(st, "state wiped by the new window")
        self.assertEqual(st["original"]["effortLevel"], "high")

    def test_a_successful_restore_still_clears_the_state(self):
        self.burning(None)
        self.run_hook()
        self.quiet(None)
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertIsNone(self.state())
        self.assertEqual(self.settings_now()["effortLevel"], "high")


class ScaleUp(ThrottleBase):
    """The other half of the ladder.

    Stepping down is only half a policy. If nothing ever says "you can afford
    the big model again", one busy hour costs him the rest of the day on
    Sonnet, and the throttle quietly becomes a downgrade with no way back.
    """

    def transcript(self, model="claude-sonnet-5", effort="low", sid="sess-1"):
        import time as _t
        path = os.path.join(self.dir, "%s.jsonl" % sid)
        row = {
            "timestamp": _t.strftime("%Y-%m-%dT%H:%M:%S.000Z", _t.gmtime()),
            "sessionId": sid, "type": "assistant", "effort": effort,
            "message": {"model": model, "usage": {"input_tokens": 1, "output_tokens": 1}},
        }
        with open(path, "w") as fh:
            fh.write(json.dumps(row) + "\n")
        return path

    def run_hook(self, prompt=PROMPT, transcript=None, sid="sess-1"):
        env = dict(os.environ, CLAUDE_CONFIG_DIR=self.dir)
        env.pop("BURN_THROTTLE_OFF", None)
        payload = {"prompt": prompt, "session_id": sid}
        if transcript:
            payload["transcript_path"] = transcript
        return subprocess.run(
            [sys.executable, THROTTLE], input=json.dumps(payload),
            capture_output=True, text=True, env=env)

    def ceiling(self, model="opus", effort="high"):
        with open(os.path.join(self.dir, "burn-ceiling.json"), "w") as fh:
            json.dump({"model": model, "effortLevel": effort}, fh)

    # -- cases ------------------------------------------------------------
    def test_a_quiet_window_offers_the_way_back_up(self):
        self.quiet(None)
        self.ceiling()
        r = self.run_hook(transcript=self.transcript())
        self.assertEqual(r.returncode, 0)
        self.assertIn("/model opus", r.stdout)
        self.assertEqual(r.stderr, "")

    def test_the_offer_never_blocks_the_prompt(self):
        """Exit 2 erases what he typed. Good news is never worth that."""
        self.quiet(None)
        self.ceiling()
        r = self.run_hook(transcript=self.transcript())
        self.assertEqual(r.returncode, 0)
        self.assertNotIn(PROMPT, r.stdout)

    def test_the_offer_does_not_repeat_in_the_same_window(self):
        self.quiet(None)
        self.ceiling()
        t = self.transcript()
        self.assertIn("/model", self.run_hook(transcript=t).stdout)
        self.assertEqual(self.run_hook(transcript=t).stdout, "")

    def test_nothing_is_offered_when_he_is_already_at_the_top(self):
        self.quiet(None)
        self.ceiling()
        r = self.run_hook(transcript=self.transcript(model="claude-opus-5",
                                                     effort="high"))
        self.assertEqual(r.stdout, "")

    def test_low_effort_alone_is_still_worth_offering_back(self):
        self.quiet(None)
        self.ceiling()
        r = self.run_hook(transcript=self.transcript(model="claude-opus-5",
                                                     effort="low"))
        self.assertIn("/effort high", r.stdout)
        self.assertNotIn("/model", r.stdout)

    def test_a_busy_window_gets_the_throttle_not_the_offer(self):
        self.burning(None)
        self.ceiling()
        r = self.run_hook(transcript=self.transcript())
        self.assertEqual(r.returncode, 2)
        self.assertEqual(r.stdout, "")

    def test_the_ceiling_is_learned_from_how_he_normally_runs(self):
        """No hardcoded model name decides what "up" means: it is whatever he
        was running when nothing was throttling him."""
        self.quiet(None)
        self.run_hook(transcript=self.transcript(model="claude-opus-5", effort="high"))
        r = self.run_hook(transcript=self.transcript(model="claude-sonnet-5", effort="low"),
                          sid="sess-2")
        self.assertIn("/model opus", r.stdout)

    def test_the_offer_returns_after_the_window_resets(self):
        import time as _t
        now = int(_t.time())
        self.ceiling()
        t = self.transcript()
        self.history(8, 8.3, now, reset_at=now + 3 * HOUR)
        self.assertIn("/model", self.run_hook(transcript=t).stdout)
        self.history(8, 8.3, now, reset_at=now + 5 * HOUR)
        self.assertIn("/model", self.run_hook(transcript=t).stdout)

    def test_the_off_switch_silences_the_offer_too(self):
        self.quiet(None)
        self.ceiling()
        open(os.path.join(self.dir, "burn-off"), "w").close()
        r = self.run_hook(transcript=self.transcript())
        self.assertEqual(r.stdout, "")

    def test_the_ceiling_is_learned_while_he_is_busy_not_only_while_he_is_quiet(self):
        """The sequence this feature exists for: a hard day at the top tier,
        the throttle steps him down, then the window goes quiet. If the ceiling
        is only sampled during quiet moments, the only thing it ever sees is
        the throttled setting, it learns THAT as normal, and the way back up
        goes silent forever."""
        self.burning(None)
        self.run_hook(transcript=self.transcript(model="claude-opus-5",
                                                 effort="xhigh"))
        self.quiet(None)
        r = self.run_hook(transcript=self.transcript(model="claude-sonnet-5",
                                                     effort="low"), sid="s2")
        self.assertIn("/model opus", r.stdout)
        self.assertIn("/effort xhigh", r.stdout)

    def test_each_session_is_told_separately(self):
        """Six sessions share one account and one state file. If the ladder is
        consumed account-wide, the first session to prompt takes the only
        warning and the five actually spending the quota are never told."""
        self.burning(None)
        first = self.run_hook(prompt="a", transcript=self.transcript(sid="one"),
                              sid="one")
        second = self.run_hook(prompt="b", transcript=self.transcript(sid="two"),
                               sid="two")
        self.assertEqual(first.returncode, 2)
        self.assertEqual(second.returncode, 2)
        self.assertIn("/effort low", second.stderr)

    def test_each_session_gets_its_own_way_back_up(self):
        self.quiet(None)
        self.ceiling()
        a = self.run_hook(transcript=self.transcript(sid="one"), sid="one")
        b = self.run_hook(transcript=self.transcript(sid="two"), sid="two")
        self.assertIn("/model opus", a.stdout)
        self.assertIn("/model opus", b.stdout)

    def test_an_already_throttled_setting_is_never_recorded_as_his_normal(self):
        """Two sessions prompting at the same instant can have the second read
        settings AFTER the first downgraded them. Remembering Sonnet as the
        original leaves him on Sonnet permanently, with nothing left that knows
        what he was on."""
        self.write_settings({"effortLevel": "low", "model": "sonnet"})
        self.burning(None)
        self.run_hook(transcript=self.transcript())
        st = self.state() or {}
        self.assertNotEqual((st.get("original") or {}).get("effortLevel"), "low")
        self.assertNotEqual((st.get("original") or {}).get("model"), "sonnet")

    def test_the_top_effort_tier_is_not_mistaken_for_the_one_below_it(self):
        """The real setting is "xhigh", which contains "high". Ranking by
        substring alone reads the top tier as the one below it and offers a
        downgrade dressed up as an upgrade."""
        self.quiet(None)
        top = self.run_hook(transcript=self.transcript(model="claude-opus-5",
                                                       effort="xhigh"))
        self.assertEqual(top.stdout, "")
        down = self.run_hook(transcript=self.transcript(model="claude-opus-5",
                                                        effort="high"), sid="s2")
        self.assertIn("/effort xhigh", down.stdout)

    def test_a_ceiling_he_has_not_run_in_a_week_stops_nagging(self):
        """If he has genuinely moved down a tier, an offer every window is a
        nag about a decision he already made."""
        import time as _t
        with open(os.path.join(self.dir, "burn-ceiling.json"), "w") as fh:
            json.dump({"model": "opus", "effortLevel": "high",
                       "ts": _t.time() - 8 * 86400}, fh)
        self.quiet(None)
        r = self.run_hook(transcript=self.transcript())
        self.assertEqual(r.stdout, "")

    def test_an_unknown_session_is_never_told_to_change_anything(self):
        """With no transcript there is no way to know what the live session is
        actually running, and guessing wrong means telling him to type
        something he is already on."""
        self.quiet(None)
        self.ceiling()
        r = self.run_hook()
        self.assertEqual(r.stdout, "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
