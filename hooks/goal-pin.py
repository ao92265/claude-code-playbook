#!/usr/bin/env python3
"""goal-pin.py - keep each session's big goal, and the side-track it is on, in view.

The problem: the user runs many sessions in thin panes. A bug turns up, the session goes
down a rabbit hole, and by the time he looks back nobody (him or Claude) can say what
the session was for. A recap he has to remember to ask for dies, so this shows
itself: a line in the statusbar, and a recap injected after a long gap.

Modes, wired in ~/.claude/settings.json:

  --prompt    UserPromptSubmit. First real prompt becomes the goal if none is set.
              After an idle gap (IDLE_SECONDS), asks Claude to open its reply with a
              three-line recap. Every turn, one short line reminds Claude of the goal
              and how to record a detour.
  --record    PostToolUse(Bash). Reads markers Claude echoes:
                goal: <x>  or  leg-done: <x>   set the goal (beats the auto one)
                asked-for: <x>                 set the goal if it is still the auto one
                detour: <x>                    push a side-track
                detour-done                    pop the latest side-track
  --session   SessionStart. On resume or compact, print the recap into context.
  --show      Print the recap (used by /recap).

State: ~/.claude/state/goal-pin/<session>.json, plus <session>.hud for the HUD shim.
Disable: CLAUDE_SKIP_HOOKS=goal-pin
"""

import fcntl
import json
import os
import re
import sys
import time

CONFIG_DIR = os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))
STATE_DIR = os.path.join(CONFIG_DIR, "state", "goal-pin")
# Claude Code keeps one <pid>.json per running session here, holding its sessionId.
SESSIONS_DIR = os.path.join(CONFIG_DIR, "sessions")
CLEARED = os.path.join(STATE_DIR, "_cleared.json")  # strips already marked done
ASKED = os.path.join(STATE_DIR, "_asked.json")      # reminders sent per closed id
IDLE_SECONDS = 1800   # a gap this long means the user has probably lost the thread
HUD_CHARS = 44        # fits a 49-column pane with the emoji prefix
GOAL_CHARS = 160
MAX_DETOURS = 5
BOARD_URL = "https://claude.ai/artifact/<your-board-id>"  # Session Strips
SOURCE_RANK ={"auto": 0, "asked-for": 1, "stated": 2}

CTRL = re.compile(r"[\x00-\x08\x0b-\x1f\x7f-\x9f]")


def skipped():
    raw = ",".join(
        x for x in (os.environ.get("CLAUDE_SKIP_HOOKS", ""), os.environ.get("OMC_SKIP_HOOKS", "")) if x
    )
    return "goal-pin" in [s.strip() for s in raw.split(",")]


def read_stdin_json():
    try:
        raw = sys.stdin.read()
        return json.loads(raw) if raw.strip() else {}
    except Exception:
        return {}


def clean(text, limit):
    text = CTRL.sub(" ", text or "")
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def key_for(data):
    sid = data.get("session_id") or os.environ.get("CLAUDE_CODE_SESSION_ID") or "default"
    return re.sub(r"[^A-Za-z0-9_.-]", "_", sid)


def load(key):
    try:
        with open(os.path.join(STATE_DIR, key + ".json")) as f:
            return json.load(f)
    except Exception:
        return {"goal": "", "source": "", "detours": [], "last_seen": 0, "last_ask": ""}


def locked(key):
    """Exclusive lock per session. Parallel Bash calls fire --record together."""
    os.makedirs(STATE_DIR, exist_ok=True)
    fh = open(os.path.join(STATE_DIR, key + ".lock"), "w")
    fcntl.flock(fh, fcntl.LOCK_EX)
    return fh


def save(key, st):
    os.makedirs(STATE_DIR, exist_ok=True)
    path = os.path.join(STATE_DIR, key + ".json")
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w") as f:
        json.dump(st, f)
    os.replace(tmp, path)
    write_hud(key, st)


def write_hud(key, st):
    path = os.path.join(STATE_DIR, key + ".hud")
    if not st.get("goal"):
        try:
            os.remove(path)
        except OSError:
            pass
        return
    lines = ["\U0001F3AF " + clean(st["goal"], HUD_CHARS)]
    if st.get("detours"):
        n = len(st["detours"])
        tag = f"↳ detour {n}: " if n > 1 else "↳ detour: "
        lines.append(tag + clean(st["detours"][-1], HUD_CHARS - len(tag) + 2))
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def recap(st):
    if not st.get("goal"):
        return "No goal recorded for this session yet."
    out = [f"Goal: {st['goal']}"]
    if st.get("detours"):
        out.append("Side-track: " + st["detours"][-1]
                   + (f" (inside {len(st['detours']) - 1} more)" if len(st["detours"]) > 1 else ""))
    else:
        out.append("Side-track: none, on the main goal")
    if st.get("last_ask"):
        out.append(f"Last ask: {st['last_ask']}")
    return "\n".join(out)


def substantive(prompt):
    p = prompt.strip()
    if p.startswith("/") and len(p.split()) < 3:
        return False
    if p.startswith("<") or p.lower().startswith("caveat:"):
        return False
    return len(p.split()) >= 4


def set_goal(st, text, source):
    text = clean(text, GOAL_CHARS)
    if not text:
        return
    if SOURCE_RANK.get(source, 0) >= SOURCE_RANK.get(st.get("source", ""), -1):
        if text != st.get("goal"):
            st["rev"] = st.get("rev", 0) + 1
        st["goal"], st["source"] = text, source


def running_sessions():
    ids = set()
    try:
        names = os.listdir(SESSIONS_DIR)
    except OSError:
        return ids
    for f in names:
        if not f.endswith(".json") or not f[:-5].isdigit():
            continue
        try:
            os.kill(int(f[:-5]), 0)
            with open(os.path.join(SESSIONS_DIR, f)) as fh:
                sid = json.load(fh).get("sessionId")
        except (OSError, ValueError):
            continue
        if sid:
            ids.add(sid)
    return ids


def load_cleared():
    try:
        with open(CLEARED) as f:
            return set(json.load(f))
    except Exception:
        return set()


def closed_strips(me):
    """Sessions that posted a strip and are no longer running. The board cannot see
    this Mac, so a live session has to mark them done or they sit on Live for ever."""
    running = running_sessions()
    if not running:  # cannot see what is running, so never guess a mass close
        return []
    cleared, out = load_cleared(), []
    for f in os.listdir(STATE_DIR):
        k = f[:-5]
        if not f.endswith(".json") or k.startswith("_") or k == me:
            continue
        if k in running or k in cleared:
            continue
        if load(k).get("posted_rev") is not None:
            out.append(k)
    return sorted(out)


def mode_prompt(data):
    key = key_for(data)
    lock = locked(key)
    st = load(key)
    prompt = data.get("prompt") or ""
    now = time.time()
    gap = now - st.get("last_seen", 0) if st.get("last_seen") else 0
    if not st.get("goal") and substantive(prompt):
        set_goal(st, prompt, "auto")
    if substantive(prompt):
        st["prompts"] = st.get("prompts", 2 if st.get("last_ask") else 0) + 1
        st["last_ask"] = clean(prompt, 120)
    st["last_seen"] = now
    save(key, st)
    lock.close()
    if not st.get("goal"):
        return
    msgs = []
    if gap >= IDLE_SECONDS:
        mins = int(gap // 60)
        msgs.append(
            f"goal-pin: the user has been away {mins} min from this session. Open your reply with a "
            "3-line recap in plain English: the goal, any side-track in progress, and the next "
            "step. Then answer.\n" + recap(st)
        )
    detour = f" Current side-track: {st['detours'][-1]}." if st.get("detours") else ""
    msgs.append(
        f"goal-pin: session goal = {st['goal']}.{detour} If this turn starts a side-track "
        "(a bug or tangent off that goal), run echo \"detour: <one line>\". When it is "
        "resolved, run echo \"detour-done\" and say what is next on the goal. To restate the "
        "goal, echo \"goal: <one line>\". Session board: when the goal, a step, the "
        "side-track or the next move changes, write this session's strip with the "
        f"ArtifactData tool (url {BOARD_URL}, collection \"sessions\", doc_id \"{key}\"; "
        "fields name, project, goal, steps [{text, done}], detour, next, state \"live\" or "
        "\"done\", updatedAt in epoch ms; get it first if you lack its version). Plain "
        "English, 3 to 7 steps. Skip trivial one-turn sessions."
    )
    gone = closed_strips(key)
    if gone:
        # An id the board never had is skipped by the session and never cleared, so
        # give each id three reminders and then let it go.
        lock = locked("_asked")
        try:
            with open(ASKED) as f:
                asked = json.load(f)
        except Exception:
            asked = {}
        gone = [k for k in gone if asked.get(k, 0) < 3][:50]
        for k in gone:
            asked[k] = asked.get(k, 0) + 1
        tmp = f"{ASKED}.tmp.{os.getpid()}"
        with open(tmp, "w") as f:
            json.dump(asked, f)
        os.replace(tmp, ASKED)
        lock.close()
    if gone:
        msgs.append(
            "goal-pin: Closed sessions still show as live on the board: "
            + ", ".join(f'"{k}"' for k in gone)
            + ". Mark them done in one ArtifactData batch (op update, collection "
            "\"sessions\", data {\"state\": \"done\"}, list the collection first for the "
            "versions; skip any id the list does not have). Do not mention this to the user."
        )
    print("<system-reminder>" + "\n".join(msgs) + "</system-reminder>")


# A marker counts only as the first word of an echo argument, so a heredoc that
# writes "Goal: ..." into a file does not move the goal. The body stops at a
# closing quote, a newline or a shell separator, so "echo goal: x && ls" is "x".
MARK = re.compile(
    r"(?:^|[;&|(\n]\s*)echo\s+(?:-[a-z]+\s+)?(?:([\"']))?"
    r"(?:(leg-done|goal|asked-for|detour)\s*:\s*((?:(?!&&|\|\||[;|>)\n]).)+?)|(detour-done)\b)"
    r"\s*(?(1)\1|(?=&&|\|\||[;|>)\n]|$))",
    re.I,
)


def mode_record(data):
    cmd = (data.get("tool_input") or {}).get("command") or ""
    hits = list(MARK.finditer(cmd))
    if not hits:
        return
    key = key_for(data)
    lock = locked(key)
    st = load(key)
    st["rev"] = st.get("rev", 0) + 1
    for m in hits:  # in the order they appear, so done-then-new keeps the new one
        if m.group(4):
            if st.get("detours"):
                st["detours"].pop()
            continue
        tag, body = m.group(2).lower(), m.group(3).strip().strip("\"'")
        if tag == "detour":
            st.setdefault("detours", []).append(clean(body, GOAL_CHARS))
            st["detours"] = st["detours"][-MAX_DETOURS:]
        elif tag == "asked-for":
            set_goal(st, body, "asked-for")
        else:
            set_goal(st, body, "stated")
    save(key, st)
    lock.close()


def mode_posted(data):
    """PostToolUse(ArtifactData): note that this session's strip is now current."""
    ti = data.get("tool_input") or {}
    key = key_for(data)
    writes = ti.get("writes") or [ti]
    done = {w.get("doc_id") for w in writes if w.get("collection") == "sessions"
            and (w.get("data") or {}).get("state") == "done" and w.get("doc_id") != key}
    if done:
        lock = locked("_cleared")
        ids = load_cleared() | done
        tmp = f"{CLEARED}.tmp.{os.getpid()}"
        with open(tmp, "w") as f:
            json.dump(sorted(ids), f)
        os.replace(tmp, CLEARED)
        lock.close()
    if not any(w.get("collection") == "sessions" and w.get("doc_id") == key for w in writes):
        return
    lock = locked(key)
    st = load(key)
    st["posted_rev"] = st.get("rev", 0)
    save(key, st)
    lock.close()


def mode_stop(data):
    """Stop. Block once per plan change until this session's strip is on the board.

    The per-turn reminder alone was ignored by every other session on day one, so
    this is the fail-closed half. One block per plan revision, never a loop.
    """
    if data.get("stop_hook_active"):
        return
    key = key_for(data)
    lock = locked(key)
    st = load(key)
    rev = st.get("rev", 0)
    # Sessions that started before the counter existed count as already busy.
    prompts = st.get("prompts", 2 if st.get("last_ask") else 0)
    due = (st.get("goal") and prompts >= 2
           and st.get("posted_rev") != rev and st.get("nagged_rev") != rev)
    if due:
        st["nagged_rev"] = rev
        save(key, st)
    lock.close()
    if due:
        sys.stderr.write(
            "goal-pin: this session's plan is not on the session board yet (or it changed). "
            f"Write its strip now with the ArtifactData tool: url {BOARD_URL}, collection "
            f"\"sessions\", doc_id \"{key}\", fields name, project, goal, steps [{{text, done}}] "
            "(3 to 7, plain English), detour, next, state \"live\", updatedAt (epoch ms). "
            "Use action get first if the doc exists and you lack its version. Then stop. "
            "This fires once per plan change.\n"
        )
        sys.exit(2)


def mode_session(data):
    if data.get("source") not in ("resume", "compact"):
        return
    st = load(key_for(data))
    if st.get("goal"):
        print("goal-pin recap (where this session was):\n" + recap(st))


def main():
    if skipped():
        return
    mode = sys.argv[1] if len(sys.argv) > 1 else "--show"
    if mode == "--show":
        data = {"session_id": sys.argv[2]} if len(sys.argv) > 2 else {}
        print(recap(load(key_for(data))))
        return
    data = read_stdin_json()
    try:
        {"--prompt": mode_prompt, "--record": mode_record, "--session": mode_session,
         "--posted": mode_posted, "--stop": mode_stop}[mode](data)
    except Exception:
        pass  # never break a turn over a statusbar nicety
    if mode == "--record":
        try:
            for f in os.listdir(STATE_DIR):
                p = os.path.join(STATE_DIR, f)
                if time.time() - os.path.getmtime(p) > 30 * 86400:
                    os.remove(p)
        except OSError:
            pass


if __name__ == "__main__":
    main()
