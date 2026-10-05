#!/usr/bin/env python3
"""UserPromptSubmit hook: step down effort, then model, before you blow a limit.

What this can and cannot do, because the difference decides the whole design:
Claude Code hooks talk through output and exit codes only. They cannot run a
slash command, and `model` and `effortLevel` are read once at session start, so
writing them to settings mid-session does nothing to the session you are in.
There is no supported way to change a live session's model or effort from here.

So the work is split. Detection is automatic. The live session gets blocked with
the exact thing to type. New sessions get the downgraded setting written into
settings.json, which they read at startup.

Blocking erases the typed prompt, so the prompt is handed straight back in the
message and written to a file. Losing what he typed would make this hated
faster than any wrong projection.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time

CONFIG_DIR = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
HERE = os.path.dirname(os.path.abspath(__file__))
BURN = os.path.join(HERE, "burn.py")

STATE = os.path.join(CONFIG_DIR, "burn-state.json")
CEILING = os.path.join(CONFIG_DIR, "burn-ceiling.json")
UP_STATE = os.path.join(CONFIG_DIR, "burn-up.json")
SETTINGS = os.path.join(CONFIG_DIR, "settings.json")
OFF_SWITCH = os.path.join(CONFIG_DIR, "burn-off")
SAVED_PROMPT = os.path.join(CONFIG_DIR, "burn-last-prompt.txt")

# Rung 1 is cheap and mild. Rung 2 is the one that actually buys headroom: the
# limits are counted per model family, so moving family is the change that
# moves the number.
LADDER = [
    ("effortLevel", "low", "/effort low"),
    ("model", "sonnet", "/model sonnet"),
]

LABEL = {"five_hour": "5 hour", "seven_day": "7 day"}

# Below this the biggest session is not the story, and naming it would send
# him to throttle the wrong pane.
BURNER_SHARE = 0.25

# Rung 2 must not land on the very next prompt. He has to be given time to
# actually type the effort change and for the burn rate to reflect it, or the
# ladder collapses into two blocks in ten seconds and tells him nothing.
RUNG_COOLDOWN = 20 * 60

# ---------------------------------------------------------------------------
# The way back up.
#
# The ladder used to only point down, which made the throttle a one way trip:
# a single busy hour left him on the small model until he happened to notice.
# The ceiling is not hardcoded, because a model name in a config file rots.
# It is learned: whatever he was actually running while nothing was throttling
# him is what "back to normal" means.
#
# The live reading comes from the transcript rather than settings.json,
# because typing /model changes the session and not the file. The transcript
# records what each turn actually ran on, which is the only honest source.
# ---------------------------------------------------------------------------
# "xhigh" contains "high", so the order is matched longest name first and the
# top tier is not read as the one below it.
EFFORT_ORDER = ["low", "medium", "high", "xhigh"]
FAMILY_ORDER = ["haiku", "sonnet", "opus"]

# A ceiling he has not run in this long is a decision he has made, not a
# downgrade to undo. Offering it every window would be a nag.
CEILING_TTL = 7 * 86400
HOUR = 3600

TAIL_BYTES = 256 * 1024


LOCK = os.path.join(CONFIG_DIR, "burn.lock")


def acquire(timeout=0.5):
    """Take the write lock, or give up and carry on without it.

    Six sessions read settings.json, change one key and write it back. Without
    this, two of them doing that in the same instant lose one of the changes.
    Failing open is deliberate: a hook that waits is a hook that makes every
    prompt feel slow, and that gets it turned off.
    """
    deadline = time.time() + timeout
    while True:
        try:
            os.mkdir(LOCK)
            return True
        except OSError:
            try:
                if time.time() - os.path.getmtime(LOCK) > 30:
                    os.rmdir(LOCK)          # a crashed holder, not a live one
                    continue
            except OSError:
                pass
            if time.time() >= deadline:
                return False
            time.sleep(0.02)


def release():
    try:
        os.rmdir(LOCK)
    except OSError:
        pass


def session_key(payload):
    """Which session is prompting. The ladder is per session: the six sharing
    the account each need telling, and only one of them is the one burning."""
    sid = payload.get("session_id") or payload.get("sessionId")
    if not sid:
        path = payload.get("transcript_path") or ""
        sid = os.path.basename(path)[:-6] if path.endswith(".jsonl") else ""
    return sid or "default"


def sess(state, sid):
    return state.setdefault("sessions", {}).setdefault(sid, {})


def read_json(path, default):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def write_json_atomic(path, data):
    """Temp file then rename. Six sessions and the user all touch settings.json, so
    a reader must never see it half written."""
    tmp = "%s.tmp.%d" % (path, os.getpid())
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
        os.replace(tmp, path)
        return True
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return False


def fmt_dur(secs):
    if secs is None:
        return "?"
    secs = int(secs)
    if secs <= 0:
        return "now"
    d, rem = divmod(secs, 86400)
    h, rem = divmod(rem, 3600)
    m = rem // 60
    if d:
        return "%dd%dh" % (d, h)
    if h:
        return "%dh%02dm" % (h, m)
    return "%dm" % m


def projection():
    """Recorded percentages only. The transcript baseline is skipped because it
    only affects the momentum ratio, never the breach decision, and a hook that
    reads two months of transcripts is a hook that stalls every prompt."""
    try:
        out = subprocess.run(
            [sys.executable, BURN, "--json", "--no-transcripts"],
            capture_output=True, text=True, timeout=10)
        if out.returncode != 0:
            return None
        return json.loads(out.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def apply_setting(key, value, state):
    """Write one throttled key into settings.json, remembering what was there.

    Only the two keys this owns are ever touched, and the original is captured
    once so a second rung cannot overwrite the memory of the first.
    """
    settings = read_json(SETTINGS, None)
    if not isinstance(settings, dict):
        return False
    if key not in state.setdefault("original", {}):
        was = settings.get(key, None)
        if was is not None and was == dict((k, v) for k, v, _ in LADDER).get(key):
            # Another session downgraded this a moment ago. Recording it as
            # his normal is how a busy hour turns into being on the small
            # model forever, with nothing left that remembers what he was on.
            pass
        else:
            state["original"][key] = was
    settings[key] = value
    if write_json_atomic(SETTINGS, settings):
        applied = state.setdefault("applied", [])
        if key not in applied:
            applied.append(key)
        return True
    return False


def restore(state):
    """Put back whatever was there before the throttle touched it.

    A single busy hour must not leave him on Sonnet for the rest of the week,
    so this runs on every quiet prompt, not on a timer that might never fire.

    Returns whether the settings are genuinely back. The state file is the only
    record of what he was on, so the caller must not delete it on a restore
    that did not happen: that pins him to the small model with nothing left to
    say why. Unreadable settings is the case that fails here, not a read only
    file, because an atomic rename only needs a writable directory.
    """
    original = state.get("original") or {}
    if not original:
        return True
    settings = read_json(SETTINGS, None)
    if not isinstance(settings, dict):
        return False
    changed = False
    for key, was in original.items():
        if was is None:
            if settings.pop(key, None) is not None:
                changed = True
        elif settings.get(key) != was:
            settings[key] = was
            changed = True
    if not changed:
        return True
    return write_json_atomic(SETTINGS, settings)


def locked_restore(state):
    held = acquire()
    try:
        return restore(state)
    finally:
        if held:
            release()


def clear_state():
    try:
        os.unlink(STATE)
    except OSError:
        pass


def top_burner(sid, rate):
    """The session spending most of the last half hour, if one stands out.

    Only ever called on a prompt that is about to be blocked, which is at most
    twice a window, because it walks the transcripts and that is far too much
    work to do on every prompt.
    """
    sys.path.insert(0, HERE)
    try:
        import fleet
        rows = fleet.build(rate=rate, session_id=sid)["sessions"]
    except (ImportError, OSError, ValueError):
        return None
    if not rows:
        return None
    top = rows[0]
    if top["share"] < BURNER_SHARE or len(rows) < 2:
        return None
    who = top["slug"] or top["session_id"][:8]
    where = fleet._short(top["cwd"]) if top["cwd"] else ""
    line = "Most of it (%.0f%%) is %s" % (top["share"] * 100, who)
    if where:
        line += " in %s" % where
    if top["is_current"]:
        line += ", which is this session"
    if top["pct_per_h"]:
        line += ", burning %.1f%%/h" % top["pct_per_h"]
    return line + "."


def rank(order, value):
    """Where a value sits in a ladder, or None if it is not on it.

    Exact first, then the longest name that appears in it. A model id carries
    its family ("claude-opus-5"), and one effort tier is a suffix of another.
    """
    if not value:
        return None
    value = str(value).lower()
    if value in order:
        return order.index(value)
    for name in sorted(order, key=len, reverse=True):
        if name in value:
            return order.index(name)
    return None


def live_session(payload):
    """What the session sending this prompt is actually running.

    Read from the tail of its own transcript: every assistant turn records the
    model it ran on and the effort it ran at.
    """
    path = payload.get("transcript_path")
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path, "rb") as fh:
            size = os.fstat(fh.fileno()).st_size
            if size > TAIL_BYTES:
                fh.seek(size - TAIL_BYTES)
                fh.readline()
            blob = fh.read().decode("utf-8", "ignore")
    except OSError:
        return None
    model = effort = None
    for line in blob.splitlines():
        if '"usage"' not in line:
            continue
        try:
            row = json.loads(line)
        except ValueError:
            continue
        if not isinstance(row, dict) or row.get("isSidechain"):
            continue          # a subagent runs on its own model, not his
        m = (row.get("message") or {}).get("model")
        if m:
            model = m
            effort = row.get("effort") or effort
    if not model:
        return None
    return {"model": model, "effortLevel": effort}


def learn_ceiling(live, now):
    """Remember the best he has actually run, and forget it if he stops.

    Returns the ceiling to compare against, or None when there is nothing
    above where he already is.
    """
    stored = read_json(CEILING, {}) or {}
    if not isinstance(stored, dict):
        stored = {}
    seen_at = stored.get("ts")
    if isinstance(seen_at, (int, float)) and seen_at < now - CEILING_TTL:
        stored = {}                     # stale: he has moved, this is his level now

    out = dict(stored)
    changed = False
    lm, sm = rank(FAMILY_ORDER, live.get("model")), rank(FAMILY_ORDER, stored.get("model"))
    if lm is not None and (sm is None or lm > sm):
        out["model"] = FAMILY_ORDER[lm]
        changed = True
    le, se = rank(EFFORT_ORDER, live.get("effortLevel")), rank(EFFORT_ORDER, stored.get("effortLevel"))
    if le is not None and (se is None or le > se):
        out["effortLevel"] = EFFORT_ORDER[le]
        changed = True
    # Written only when it moves or when the last sighting is getting old.
    # This runs on every prompt in every session, so it must not be a write
    # on every prompt in every session.
    last = stored.get("ts") if isinstance(stored.get("ts"), (int, float)) else 0
    if changed or now - last > HOUR:
        out["ts"] = now
        write_json_atomic(CEILING, out)
    else:
        out["ts"] = last
    return out


def offer_scale_up(verdict, payload, sid, live, now):
    """Tell him what to type to get back up, at most once per window."""
    if not verdict.get("can_scale_up"):
        return 0
    if not live:
        return 0                        # no idea what he is on: say nothing

    ceiling = read_json(CEILING, {}) or {}
    steps = []
    lm, cm = rank(FAMILY_ORDER, live.get("model")), rank(FAMILY_ORDER, ceiling.get("model"))
    if lm is not None and cm is not None and cm > lm:
        steps.append("/model %s" % FAMILY_ORDER[cm])
    le, ce = rank(EFFORT_ORDER, live.get("effortLevel")), rank(EFFORT_ORDER, ceiling.get("effortLevel"))
    if le is not None and ce is not None and ce > le:
        steps.append("/effort %s" % EFFORT_ORDER[ce])
    if not steps:
        return 0

    five = verdict.get("five_hour") or {}
    window_id = five.get("resets_at") or verdict.get("seven_day", {}).get("resets_at")
    up = read_json(UP_STATE, {}) or {}
    seen = (up.get("sessions") or {}).get(sid)
    if seen == window_id:
        return 0                        # already said it to this session

    up.setdefault("sessions", {})[sid] = window_id
    write_json_atomic(UP_STATE, up)
    slack = verdict.get("slack") or 0
    where = "%s at %.0f%%" % (LABEL["five_hour"], five.get("used_percentage") or 0.0)
    if slack >= 20:
        room = "and barely touching it"
    else:
        room = "with about %.0fx the room you are using" % slack
    sys.stdout.write(
        "BURN: %s %s. You are running below your usual: type  %s  to go back "
        "up.\n" % (where, room, "  and  ".join(steps)))
    return 0


def notice(state, sid, key, w):
    """Say it once per session, without stopping the prompt.

    The block has already happened somewhere in this window and the downgrade
    is already applied account wide, so there is nothing for him to do. This
    exists only so a session that never saw the block is not left wondering
    why it is suddenly on low effort.
    """
    me = sess(state, sid)
    if me.get("told") == state.get("window_id"):
        return 0
    me["told"] = state.get("window_id")
    write_json_atomic(STATE, state)
    applied = ", ".join(state.get("applied") or []) or "nothing"
    sys.stdout.write(
        "BURN: %s window at %.0f%%, already throttled (%s) for the rest of "
        "this window. Nothing to do.\n"
        % (LABEL[key], w.get("used_percentage") or 0.0, applied))
    return 0


def main():
    if os.path.exists(OFF_SWITCH) or os.environ.get("BURN_THROTTLE_OFF"):
        return 0

    payload = {}
    try:
        raw = sys.stdin.read()
        if raw.strip():
            payload = json.loads(raw)
    except ValueError:
        payload = {}

    verdict = projection()
    if not verdict:
        return 0

    # Learned on every prompt, busy or quiet. Sampled only while quiet, the
    # only thing it would ever see is the throttled setting, and it would
    # learn that as normal.
    live = live_session(payload)
    if live:
        learn_ceiling(live, time.time())

    sid = session_key(payload)
    state = read_json(STATE, {}) or {}

    breaching = [k for k in ("five_hour", "seven_day")
                 if verdict.get(k, {}).get("will_breach")]

    if not breaching:
        # Nothing projected. If the throttle is holding anything, give it back.
        # Settings only affect the NEXT session though, so the live one still
        # needs telling, which is what the offer does.
        if state.get("applied") and not locked_restore(state):
            return 0                    # keep the record until it is really back
        clear_state()
        return offer_scale_up(verdict, payload, sid, live, time.time())

    key = breaching[0]
    w = verdict[key]
    window_id = w.get("resets_at")

    # A new window is a clean slate: old latches and old downgrades do not
    # carry across a reset.
    if (state.get("window_id") != window_id or state.get("window") != key
            or "blocked_rung" not in state):
        if state.get("applied") and not locked_restore(state):
            return 0                    # the new window must not wipe the record
        # "blocked_rung" missing means state written by the old per session
        # build. Discarding it is cheaper and safer than migrating it.
        state = {"window": key, "window_id": window_id, "sessions": {},
                 "blocked_rung": 0, "blocked_at": 0}

    # The rung is per WINDOW, not per session. The downgrade it writes is
    # account wide, so the interruption only has to happen once: latching it
    # per session meant every new tab and every /clear minted a fresh id and
    # earned the same block again, which is what made the hook feel broken.
    rung = int(state.get("blocked_rung", 0))

    # After he resends, this rung never blocks again in this window, whether
    # or not he actually switched. A hook that blocks every prompt makes
    # Claude Code unusable, which is worse than any limit.
    since = time.time() - float(state.get("blocked_at") or 0)
    blocked_out = (rung >= len(LADDER)) or (rung > 0 and since < RUNG_COOLDOWN)

    if blocked_out:
        return notice(state, sid, key, w)

    setting_key, setting_value, type_this = LADDER[rung]

    held = acquire()
    try:
        applied = apply_setting(setting_key, setting_value, state)
        state["blocked_rung"] = rung + 1
        state["blocked_at"] = time.time()
        sess(state, sid)["told"] = window_id
        write_json_atomic(STATE, state)
    finally:
        if held:
            release()

    prompt = payload.get("prompt") or ""
    try:
        with open(SAVED_PROMPT, "w", encoding="utf-8") as fh:
            fh.write(prompt)
    except OSError:
        pass

    lines = [
        "BURN THROTTLE: %s window at %.0f%%, burning %.1f%%/h."
        % (LABEL[key], w["used_percentage"],
           (w.get("rate_shown") if w.get("rate_shown") is not None
            else w.get("rate_now")) or 0.0),
        "Hits 100%% in %s. Window resets in %s. Projected %.0f%% at reset."
        % (fmt_dur(w["seconds_to_100"]), fmt_dur(w["resets_in_s"]),
           w["projected_at_reset"] or 0.0),
    ]
    # Which session, not just how fast. Told only the rate, he has to go and
    # look, and that is the step that does not happen.
    burner = top_burner(sid, w.get("rate_now"))
    if burner:
        lines.append(burner)
    lines += [
        "",
        "Type  %s  and send again." % type_this,
    ]
    if applied:
        lines.append("New sessions will start on %s=%s until this window resets."
                     % (setting_key, setting_value))
    if prompt:
        lines += ["", "Your prompt, saved to %s:" % SAVED_PROMPT, "---", prompt, "---"]
    lines += ["", "Off switch: touch %s" % OFF_SWITCH]

    sys.stderr.write("\n".join(lines) + "\n")
    return 2


if __name__ == "__main__":
    sys.exit(main())
