#!/usr/bin/env python3
"""Run Referee — out-of-band watchdog for long unattended Claude Code runs.

Every 10 minutes (launchd: com.example.claude-run-referee) it scans active
session transcripts under ~/.claude/projects/*/*.jsonl, applies PURE MECHANICAL
heuristics (no LLM), and enforces verdicts via sentinel files that a PreToolUse
guard hook (run-referee-guard.sh) honors inside the run.

Verdict policy (false kill >> missed kill):
  KILL  — mechanical certainty only:
            * cumulative output tokens > per-run budget
            * sustained API-error retry loop (>= ERR_KILL errors in the window,
              zero successful assistant messages between them, 2 cycles in a row)
  PAUSE — fuzzy signals; can never escalate to kill:
            * no tool activity for NOPROGRESS_CYCLES consecutive cycles while
              the session keeps emitting messages (thrash without progress)
            * still actively working WALLCLOCK_PAUSE seconds after the referee
              first metered it (the 4h session cap, surfaced not enforced-by-kill)
  Anything else — continue.

Incremental: per-session byte cursor + running totals in state.json, so huge
JSONLs are read once. Enforcement writes:
  ~/.claude/run-referee/sentinels/<session-uuid>   (verdict + reason inside)
  ~/.claude/handoffs/referee-<session-uuid>.md     (morning-readable handoff)
plus a macOS notification. Resume = rm the sentinel (instructions in both).

Exclusions: sessions idle > ACTIVE_WINDOW are ignored (nothing to stop);
this referee session itself is never exempt — REFEREE_EXEMPT env in a run
plus a sentinel-free state is the only off switch, by design.
"""
import json, os, glob, subprocess, sys, time, datetime, fcntl

HOME = os.path.expanduser("~")
PROJECTS = os.path.join(HOME, ".claude", "projects")
BASE = os.path.join(HOME, ".claude", "run-referee")
SENTINELS = os.path.join(BASE, "sentinels")
STATE_PATH = os.path.join(BASE, "state.json")
LOG = os.path.join(BASE, "log.jsonl")
HANDOFFS = os.path.join(HOME, ".claude", "handoffs")

# Budget calibrated 2026-07-02 from the top-20 largest local sessions:
# min 119K / median 899K / p90 1.70M / max 2.00M output tokens (mixed legit +
# runaway). Budget sits above legit p90 so it is the blast-radius cap, NOT the
# fast trigger — the error-loop and no-progress heuristics do the early catching.
TOKEN_BUDGET = int(os.environ.get("REFEREE_TOKEN_BUDGET", "1500000"))
ACTIVE_WINDOW = 12 * 60          # session counts as active if written within this window
MIN_RUN_AGE = 45 * 60            # only referee runs older than this
ERR_KILL = 8                     # api errors in one window, no progress between, 2 cycles => kill
NOPROGRESS_CYCLES = 3            # cycles with messages but zero tool_use => pause

# Wall-clock cap. CLAUDE.md: "Session cap 4h. Loop/background >4h = usage leak
# -- surface + cancel." Nothing enforced that until now: afk, carryon and
# oneshot all promise a 4h stop in prose with no code behind it, and the only
# mechanical ceilings here were token spend and error loops.
#
# PAUSE, never kill: a 4h session can be perfectly legitimate, and this file's
# standing policy is that a false kill costs far more than a missed one.
# Measured from first_seen_epoch (the referee's own meter), NOT from file birth,
# for the same reason the token meter is: a session already running when the
# referee first saw it must not be charged for time nobody was watching.
# ACTIVE_WINDOW already excludes idle sessions, so an old shell someone left
# open never trips this -- only a session still emitting work does.
WALLCLOCK_PAUSE = int(os.environ.get("REFEREE_WALLCLOCK_PAUSE", str(4 * 60 * 60)))

# Context-depth cap. The wall clock was never the real quality variable; context
# depth is. rule-drift.py measured it over 2,805 scored replies: rule compliance
# runs 69% while a session is under 100k tokens of live context and 46% once it
# passes 400k. A session that deep is still working, it is just working worse,
# and CLAUDE.md already says to write a handoff and clear at about half.
#
# So: same treatment as the wall clock. PAUSE, never kill, and the guard hook
# still lets the paused session Write into ~/.claude/reboots/, so it hands itself
# off rather than being stranded.
#
# Two exclusions, both learned from rule-drift's own false-positive classes:
# sidechain records are subagents (their context is not the parent's), and an
# entrypoint other than "cli" is a headless automation run with nobody sitting
# there to reboot it.
CONTEXT_PAUSE = int(os.environ.get("REFEREE_CONTEXT_PAUSE", "400000"))
CONTEXT_CYCLES = 2               # sustained across cycles, so a pre-compaction spike is ignored

# Rotation. Every tier above this ends the same way: the session stops and waits
# for the user to notice. Rotation is the same measurement with a better ending --
# the session writes its own reboot handoff, clears itself, and carries on,
# with nobody typing anything.
#
# It fires EARLIER than the pause lines on purpose. A session that rotates at
# 250k never reaches the 400k pause, and rule-drift's numbers say that is the
# right place to do it: compliance runs 69% under 100k and 46% past 400k, so
# the useful move is to reset the context, not to stop the work.
#
# Rotation can decline for good reasons (the session is not in tmux, a
# permission prompt is on screen, the handoff never got written). When it does,
# nothing is lost: the pause tiers below are untouched and still catch the
# session at exactly the point they always did. This is strictly an earlier,
# gentler outcome bolted in front of the existing behaviour, never a
# replacement for it.
CONTEXT_ROTATE = int(os.environ.get("REFEREE_CONTEXT_ROTATE", "250000"))
WALLCLOCK_ROTATE = int(os.environ.get("REFEREE_WALLCLOCK_ROTATE", str(int(3.5 * 60 * 60))))
ROTATE_CYCLES = 2                # same sustained guard as the pause tier
ROTATE_BACKOFF = 15 * 60         # do not re-fire at a session already rotating
ROTATOR = os.path.join(HOME, ".claude", "scripts", "session-rotate.sh")
TMUX_MAP = os.path.join(HOME, ".claude", "state", "tmux-map")
OPTOUT_DIR = os.path.join(HOME, ".claude", "state", "rotate-optout")  # /keep pins, one file per pane
ROTATE_ENABLED = os.environ.get("REFEREE_ROTATE", "1") not in ("0", "false", "no")
ERROR_MARKERS = ("overloaded", "rate limit", "hit your session limit", "api error",
                 "529", "500 internal", "503 service")

def now_iso():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")

def log_event(ev):
    ev["ts"] = now_iso()
    with open(LOG, "a") as f:
        f.write(json.dumps(ev) + "\n")

def notify(title, body):
    try:
        subprocess.run(["osascript", "-e",
                        'display notification "{}" with title "{}"'.format(
                            body.replace('\\', '').replace('"', "'")[:180],
                            title.replace('"', "'"))],
                       timeout=10, capture_output=True)
    except Exception:
        pass

def analyze_chunk(chunk_lines):
    """Mechanical stats over newly-appended JSONL lines."""
    out_tokens = 0
    tool_uses = 0
    api_errors = 0
    assistant_ok = 0
    max_ctx = 0
    headless = False
    for ln in chunk_lines:
        try:
            j = json.loads(ln)
        except Exception:
            continue
        msg = j.get("message") or {}
        usage = msg.get("usage") or j.get("usage") or {}
        out_tokens += usage.get("output_tokens") or 0
        if j.get("entrypoint") not in (None, "cli"):
            headless = True
        # Live context = everything on the request, cached or not. Sidechains are
        # subagent turns and carry their own separate context, so they must not
        # be read as the parent session's depth.
        if not j.get("isSidechain"):
            ctx = 0
            for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"):
                v = usage.get(k)
                if isinstance(v, int):
                    ctx += v
            max_ctx = max(max_ctx, ctx)
        content = msg.get("content")
        if isinstance(content, list):
            for c in content:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    tool_uses += 1
        if j.get("type") == "assistant" and usage.get("output_tokens"):
            assistant_ok += 1
        # API errors surface as harness-synthesized assistant messages:
        # message.model == "<synthetic>", zero output tokens, error text in content.
        if msg.get("model") == "<synthetic>":
            blob = json.dumps(msg.get("content", ""))[:2000].lower()
            if any(m in blob for m in ERROR_MARKERS):
                api_errors += 1
    return {"out_tokens": out_tokens, "tool_uses": tool_uses,
            "api_errors": api_errors, "assistant_ok": assistant_ok,
            "max_ctx": max_ctx, "headless": headless}

def recent_asks(path, limit=5, tail_bytes=2_000_000):
    """Last few real user prompts from the transcript tail. Mechanical, no LLM.

    The referee handoff is a morning-readable note; totals alone do not say
    what the session was FOR. Tool results and harness noise also arrive as
    type=user entries, so keep only entries with actual text that does not
    look like markup ("<command-name>...", "[Request interrupted...").
    Tail-bounded: transcripts reach hundreds of MB and this runs inside a
    10-minute launchd cycle.
    """
    asks = []
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as f:
            if size > tail_bytes:
                f.seek(size - tail_bytes)
                f.readline()  # drop the partial line at the seek point
            for ln in f.read().decode("utf-8", errors="replace").splitlines():
                try:
                    j = json.loads(ln)
                except Exception:
                    continue
                if j.get("type") != "user":
                    continue
                content = (j.get("message") or {}).get("content")
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    text = " ".join(c.get("text", "") for c in content
                                    if isinstance(c, dict) and c.get("type") == "text")
                else:
                    continue
                text = " ".join(text.split())
                if not text or text.startswith("<") or text.startswith("["):
                    continue
                asks.append(text[:200])
    except Exception:
        return []
    return asks[-limit:]

def enforce(uuid, verdict, reason, s, path):
    os.makedirs(SENTINELS, exist_ok=True)
    os.makedirs(HANDOFFS, exist_ok=True)
    spath = os.path.join(SENTINELS, uuid)
    with open(spath, "w") as f:
        # transcript_path recorded so the guard hook can verify a FULL-path
        # match — a bare uuid reused across project dirs must not block the
        # wrong session.
        json.dump({"verdict": verdict, "reason": reason, "ts": now_iso(),
                   "transcript_path": path}, f)
    asks = recent_asks(path)
    asks_md = "\n".join(f"- {a}" for a in asks) if asks else "_none captured in the transcript tail_"
    hpath = os.path.join(HANDOFFS, f"referee-{uuid}.md")
    with open(hpath, "w") as f:
        f.write(f"""# Run Referee {verdict.upper()} — session {uuid}
_{now_iso()}_

**Reason:** {reason}

**Session totals:** ~{s.get('total_out_tokens', 0):,} output tokens, {s.get('total_tool_uses', 0)} tool calls seen by referee.

**Recent asks (oldest to newest):**
{asks_md}

The next tool call in that session will be blocked by run-referee-guard.sh with
this reason, EXCEPT a Write into ~/.claude/reboots/ — the blocked session is
told to write its own rich reboot handoff before halting. If it did, a fresh
session in that folder picks it up on /clear or startup automatically. The thin
stop-handoff also fires when it halts. Resume from a FRESH session, don't
--resume the bloated one.

To lift the block (resume the same session anyway):
    rm ~/.claude/run-referee/sentinels/{uuid}
""")
    notify(f"Run Referee: {verdict.upper()}", reason)
    log_event({"event": verdict, "session": uuid, "reason": reason,
               "total_out_tokens": s.get("total_out_tokens", 0)})

def pinned(map_file):
    """True when the user pinned this pane with /keep, so rotation leaves it alone.

    A pinned session falls through to the pause tiers, which notify but never
    clear the screen. Pane ids are reused after a tmux restart, so a pin whose
    pane tmux no longer lists is stale and gets dropped, or it would silently
    protect some unrelated new terminal. If tmux cannot be asked at all, keep
    the pin: a missed rotation costs nothing, a wrongly cleared screen does.
    """
    try:
        m = json.load(open(map_file))
    except Exception:
        return False
    pane = str(m.get("pane", ""))
    marker = os.path.join(OPTOUT_DIR, pane.lstrip("%"))
    if not pane or not os.path.exists(marker):
        return False
    cmd = ["tmux"] + (["-S", m["socket"]] if m.get("socket") else []) + \
          ["list-panes", "-a", "-F", "#{pane_id}"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=5,
                           env=dict(os.environ, PATH="/opt/homebrew/bin:/usr/local/bin:" + os.environ.get("PATH", "")))
    except Exception:
        return True
    if r.returncode == 0 and pane not in r.stdout.split():
        try:
            os.remove(marker)
        except OSError:
            pass
        log_event({"event": "pin-dropped", "pane": pane, "why": "pane no longer exists"})
        return False
    return True

def rotate(uuid, reason, path):
    """Hand the session to the rotator and return immediately.

    Detached deliberately: the rotator waits minutes for the handoff to be
    written, and the referee must not spend its 10-minute cycle blocked on one
    session while every other session goes unmetered. The rotator holds its own
    per-pane lock, so firing at one that is already rotating is a no-op.

    Returns False when rotation is not even attemptable, which is the signal to
    fall through to the pause tiers rather than assume the session was handled.
    """
    if not ROTATE_ENABLED or not os.path.exists(ROTATOR):
        return False
    # No tmux map means the session is a bare terminal. Nothing can type into
    # one from here, so this is a normal outcome, not an error.
    map_file = os.path.join(TMUX_MAP, uuid + ".json")
    if not os.path.exists(map_file):
        return False
    if pinned(map_file):
        return False
    try:
        subprocess.Popen([ROTATOR, uuid, reason],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    except Exception as e:
        log_event({"event": "rotate-failed", "session": uuid, "error": str(e)[:200]})
        return False
    log_event({"event": "rotate", "session": uuid, "reason": reason})
    return True

def referee_session(path, state, dry=False):
    uuid = os.path.basename(path)[:-6]  # strip .jsonl
    st = os.stat(path)
    age = time.time() - st.st_mtime
    if age > ACTIVE_WINDOW:
        return None
    if uuid not in state:
        # First sight: start the meter HERE, never retro-charge history — a
        # pre-existing long session must not be killed for tokens spent before
        # the referee was watching.
        state[uuid] = {"offset": st.st_size, "total_out_tokens": 0, "total_tool_uses": 0,
                       "first_seen": now_iso(), "first_seen_epoch": time.time(),
                       "err_cycles": 0, "noprogress_cycles": 0, "path": path}
        return None
    s = state[uuid]
    if os.path.exists(os.path.join(SENTINELS, uuid)):
        return None  # already enforced
    if st.st_size < s["offset"]:
        # file truncated/rewritten below our cursor (compaction, rewrite):
        # reset to 0 or the referee goes permanently blind until the file
        # regrows past the stale offset.
        s["offset"] = 0
    with open(path, "rb") as f:
        f.seek(s["offset"])
        chunk = f.read().decode("utf-8", errors="replace")
        s["offset"] = f.tell()
    lines = chunk.splitlines()
    a = analyze_chunk(lines)
    s["total_out_tokens"] += a["out_tokens"]
    s["total_tool_uses"] += a["tool_uses"]

    run_age = time.time() - s.get("first_seen_epoch", time.time())
    if run_age < MIN_RUN_AGE:
        return None

    # KILL 1: budget (mechanical certainty)
    if s["total_out_tokens"] > TOKEN_BUDGET:
        if not dry:
            enforce(uuid, "kill", f"token budget exceeded: {s['total_out_tokens']:,} > {TOKEN_BUDGET:,} output tokens", s, path)
        return ("kill", "budget")
    # KILL 2: sustained API-error loop, two consecutive cycles
    if a["api_errors"] >= ERR_KILL and a["assistant_ok"] == 0:
        s["err_cycles"] += 1
    else:
        s["err_cycles"] = 0
    if s["err_cycles"] >= 2:
        if not dry:
            enforce(uuid, "kill", f"API-error retry loop: >= {ERR_KILL} errors/cycle, no successful messages, 2 cycles", s, path)
        return ("kill", "error-loop")
    # PAUSE: wall-clock cap. Session is still active (ACTIVE_WINDOW) and has
    # been running longer than the cap, so it is working, not just left open.
    #
    # Metered from its own `wallclock_since`, set the first time this rule sees
    # the session, for the same reason the token meter starts at first sight:
    # never retro-charge history. Sessions already in state.json when this rule
    # shipped were metered under the old policy, and pausing them on the first
    # cycle would stop live work nobody was warned about. They get a full cap
    # from here. A session first seen after this rule ships starts its clock at
    # first sight, so the cap is honest for everything going forward.
    if "wallclock_since" not in s:
        s["wallclock_since"] = time.time()
    wall_age = time.time() - s["wallclock_since"]

    # ROTATE: tried before either pause tier, so a session rotates instead of
    # stalling. Headless runs are excluded for the same reason the context
    # pause excludes them: nobody is sitting at one, and a /clear typed into an
    # automation run would derail it.
    if a["headless"]:
        s["headless"] = True
    if a["max_ctx"] >= CONTEXT_ROTATE and not s.get("headless"):
        s["rot_cycles"] = s.get("rot_cycles", 0) + 1
        s["rot_ctx"] = max(s.get("rot_ctx", 0), a["max_ctx"])
    elif a["max_ctx"]:
        s["rot_cycles"] = 0      # a real reading below the line: auto-compact landed
    if not s.get("headless") and (time.time() - s.get("last_rotate", 0)) > ROTATE_BACKOFF:
        rot_reason = None
        if s.get("rot_cycles", 0) >= ROTATE_CYCLES:
            rot_reason = ("context depth {:,} tokens live, sustained over {} cycles"
                          .format(s.get("rot_ctx", 0), ROTATE_CYCLES))
            rot_tag = "context-depth"
        elif wall_age > WALLCLOCK_ROTATE:
            rot_reason = "{:.1f}h into the run".format(wall_age / 3600)
            rot_tag = "wallclock"
        if rot_reason and not dry and rotate(uuid, rot_reason, path):
            s["last_rotate"] = time.time()
            s["rot_cycles"] = 0
            return ("rotate", rot_tag)

    if wall_age > WALLCLOCK_PAUSE:
        if not dry:
            enforce(uuid, "pause",
                    f"wall-clock cap: still active {wall_age / 3600:.1f}h into the run "
                    f"(cap {WALLCLOCK_PAUSE / 3600:.1f}h)", s, path)
        return ("pause", "wallclock")
    # PAUSE: context depth. Placed after the wall clock deliberately — if both
    # apply, the older, better-understood reason is the one he gets told.
    if a["headless"]:
        s["headless"] = True
    if a["max_ctx"] >= CONTEXT_PAUSE and not s.get("headless"):
        s["deep_cycles"] = s.get("deep_cycles", 0) + 1
        s["deepest_ctx"] = max(s.get("deepest_ctx", 0), a["max_ctx"])
    elif a["max_ctx"]:
        # a real reading below the line resets it: auto-compact has landed
        s["deep_cycles"] = 0
    if s.get("deep_cycles", 0) >= CONTEXT_CYCLES:
        if not dry:
            enforce(uuid, "pause",
                    f"context depth: {s.get('deepest_ctx', 0):,} tokens live, sustained over "
                    f"{CONTEXT_CYCLES} cycles (cap {CONTEXT_PAUSE:,}). Rule compliance is "
                    f"measurably worse past this line — write a reboot handoff and clear",
                    s, path)
        return ("pause", "context-depth")
    # PAUSE: messages flowing but zero tool activity across cycles
    if lines and a["tool_uses"] == 0 and a["assistant_ok"] > 0:
        s["noprogress_cycles"] += 1
    elif a["tool_uses"] > 0:
        s["noprogress_cycles"] = 0
    if s["noprogress_cycles"] >= NOPROGRESS_CYCLES:
        if not dry:
            enforce(uuid, "pause", f"no tool activity for {NOPROGRESS_CYCLES} consecutive cycles while still emitting messages", s, path)
        return ("pause", "no-progress")
    return None

def main():
    os.makedirs(BASE, exist_ok=True)
    # single-instance lock: a slow scan must not race the next launchd cycle
    # into a read-modify-write collision on state.json.
    lock = open(os.path.join(BASE, ".lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        log_event({"event": "skipped", "reason": "previous cycle still active (lock held)"})
        return 0
    state = {}
    if os.path.exists(STATE_PATH):
        try:
            with open(STATE_PATH) as f:
                state = json.load(f)
        except Exception as e:
            log_event({"event": "error", "error": f"state.json unreadable, starting fresh: {e}"[:300]})
    verdicts = []
    # recursive: subagent/workflow transcripts live under
    # <project>/<parent-uuid>/subagents/**/*.jsonl — a runaway subagent must
    # be metered too, not just its parent session.
    for path in glob.glob(os.path.join(PROJECTS, "**", "*.jsonl"), recursive=True):
        try:
            v = referee_session(path, state)
            if v:
                verdicts.append((os.path.basename(path), v))
        except Exception as e:
            log_event({"event": "error", "session": os.path.basename(path), "error": str(e)[:300]})
    # prune state for sessions whose file is gone or untouched in 7 days
    cutoff = time.time() - 7 * 86400
    for u in list(state):
        p = state[u].get("path")
        if not p or not os.path.exists(p) or os.stat(p).st_mtime < cutoff:
            del state[u]
    tmp = STATE_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, STATE_PATH)  # atomic — no partial state.json on crash
    with open(os.path.join(BASE, "heartbeat"), "w") as f:
        f.write(now_iso() + "\n")
    log_event({"event": "cycle", "verdicts": [f"{u}:{v[0]}" for u, v in verdicts]})
    return 0

if __name__ == "__main__":
    # The watchdog must never die silently — that is the exact failure mode it
    # exists to catch in others.
    try:
        sys.exit(main())
    except Exception as e:
        try:
            log_event({"event": "crash", "error": str(e)[:500]})
            notify("Run Referee CRASHED", str(e)[:150])
        finally:
            sys.exit(1)
