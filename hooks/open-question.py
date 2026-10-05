#!/usr/bin/env python3
"""open-question.py — pin the user's question so it can't scroll away.

The problem: the user asks something in the same message that gives me work. I do the
work, the question disappears under tool output, and it never gets answered.

Three modes, wired in ~/.claude/settings.json:

  --prompt   UserPromptSubmit. If the prompt contains a question, park it in this
             session's slot. Then, if a slot is open, print a nag block to stdout
             so it lands in Claude's context this turn. ~40 tokens while pinned,
             zero when nothing is pinned.

  --stop     Stop hook. If a question is still open and hasn't been nagged, exit 2
             to refuse the stop ("answer it first"). Blocks at most ONCE per
             question, so autonomous loops can't get wedged.

  --resolve  Clear the slot. Claude runs this after answering; /q done runs it too.
  --show     Print the open question (used by the /q command).
  --pin TEXT Pin a question manually.

State: ~/.claude/state/open-question/<session>.json  (+ .hud one-liner for the
statusline). Per session, so the 12 concurrent sessions don't bleed into each other.

Python not bash because the prompt is arbitrary user text — quotes and newlines
break the sed-based JSON extraction the shell hooks use.

Disable: remove the open-question.py entries from ~/.claude/settings.json.
"""

import json
import os
import re
import sys
import time

STATE_DIR = os.path.join(
    os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude")),
    "state",
    "open-question",
)

MAX_TURNS = 6          # drop a pin nobody has cleared after this many turns
MAX_AGE_SECONDS = 1800 # ...or 30 minutes, whichever comes first
HUD_WIDTH = 70
MAX_QUESTIONS = 3


def read_stdin_json():
    try:
        raw = sys.stdin.read()
    except Exception:
        return {}
    if not raw.strip():
        return {}
    try:
        return json.loads(raw)
    except Exception:
        return {}


def session_key(payload):
    # CLAUDE_CODE_SESSION_ID is exported into the Bash tool environment and holds
    # the same UUID the hooks receive on stdin — that's what lets `--resolve`,
    # run as a plain shell command, target this session's slot and not another's.
    key = (
        payload.get("session_id")
        or os.environ.get("CLAUDE_CODE_SESSION_ID")
        or os.environ.get("CLAUDE_SESSION_ID")
        or os.environ.get("CLAUDECODE_SESSION_ID")
        or ""
    )
    if not key:
        transcript = payload.get("transcript_path") or ""
        found = re.search(r"[0-9a-fA-F][0-9a-fA-F-]{35}", transcript)
        key = found.group(0) if found else "default"
    return re.sub(r"[^A-Za-z0-9_.-]", "_", key)[:80] or "default"


def paths(key):
    return (
        os.path.join(STATE_DIR, key + ".json"),
        os.path.join(STATE_DIR, key + ".hud"),
    )


def load(key):
    state_path, _ = paths(key)
    try:
        with open(state_path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return None


def save(key, state):
    state_path, hud_path = paths(key)
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = state_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(state, handle)
    os.replace(tmp, state_path)
    with open(hud_path, "w", encoding="utf-8") as handle:
        handle.write(hud_line(state) + "\n")


def clear(key):
    for path in paths(key):
        try:
            os.remove(path)
        except OSError:
            pass


def prune_stale():
    """Keep the shared state dir from silting up — it already holds 1600+ files."""
    cutoff = time.time() - 7 * 86400
    try:
        for name in os.listdir(STATE_DIR):
            path = os.path.join(STATE_DIR, name)
            try:
                if os.path.getmtime(path) < cutoff:
                    os.remove(path)
            except OSError:
                pass
    except OSError:
        pass


def hud_line(state):
    text = state["questions"][0]
    if len(state["questions"]) > 1:
        text += "  (+%d more)" % (len(state["questions"]) - 1)
    # Drop C0 control bytes and DEL before this reaches the statusline. Python's \s
    # covers space, tab, newline, CR, FF and VT but NOT ESC (\x1b) or BEL (\x07), so
    # an escape sequence pasted into a prompt would otherwise be written to the
    # terminal verbatim: ANSI visual spoofing, or clipboard hijack via OSC 52.
    # (OWASP GenAI/LLM Top 10 2026, LLM10 Improper Output Handling, terminal sinks.)
    text = re.sub(r"[\x00-\x08\x0b-\x1f\x7f]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > HUD_WIDTH:
        text = text[: HUD_WIDTH - 1].rstrip() + "…"
    return "❓ " + text


# --- question extraction -------------------------------------------------

# Split on sentence enders and newlines, keeping the terminator so we can tell
# which fragments are questions.
SPLIT = re.compile(r"(?<=[.?!])\s+|\n+")

# Fenced code and inline code often contain "?" (ternaries, regex, query strings)
# and would otherwise pin garbage.
FENCE = re.compile(r"```.*?```|`[^`\n]*`", re.DOTALL)
URL = re.compile(r"https?://\S+")


def extract_questions(prompt):
    """Return (questions, is_pure) — is_pure means the prompt was ONLY questions."""
    stripped = FENCE.sub(" ", prompt)
    stripped = URL.sub(" ", stripped)

    questions, residue = [], []
    for chunk in SPLIT.split(stripped):
        chunk = chunk.strip()
        if not chunk:
            continue
        if chunk.endswith("?"):
            questions.append(chunk)
        else:
            residue.append(chunk)

    if not questions:
        return [], False

    questions = [q for q in questions if len(q) > 3][:MAX_QUESTIONS]
    if not questions:
        return [], False

    # "Pure" = nothing of substance besides the questions themselves. Those get
    # answered on the spot, so they self-clear at stop instead of nagging.
    is_pure = sum(len(r) for r in residue) < 12
    return questions, is_pure


def should_skip(prompt):
    text = prompt.strip()
    if not text:
        return True
    if text.startswith("/"):          # slash command
        return True
    if text.startswith("<"):          # command expansion / injected block
        return True
    return False


def expired(state):
    return (
        state.get("turn", 0) > MAX_TURNS
        or (time.time() - state.get("pinned_at", 0)) > MAX_AGE_SECONDS
    )


def render_nag(state):
    lines = ["OPEN QUESTION — asked %d turn(s) ago, still unanswered:" % state.get("turn", 1)]
    for question in state["questions"]:
        lines.append('  "%s"' % re.sub(r"\s+", " ", question).strip())
    lines.append(
        "Answer it in the FIRST LINE of your reply, before any tool call. "
        "If it genuinely needs work done first, say \"answering after <X>\". "
        "Once answered, run: python3 ~/.claude/hooks/open-question.py --resolve"
    )
    return "\n".join(lines)


# --- modes ---------------------------------------------------------------

def mode_prompt(payload):
    key = session_key(payload)
    prompt = payload.get("prompt") or ""
    state = load(key)

    if state and expired(state):
        clear(key)
        state = None

    if not should_skip(prompt):
        questions, is_pure = extract_questions(prompt)
        if is_pure:
            # The question IS the whole message — it can't get buried under work,
            # and blocking the stop on it would fire falsely every time I answer
            # normally. Rule 0 in answer-shape-nudge.sh covers this case for free.
            questions = []
        if questions:
            state = {
                "questions": questions,
                "pure": is_pure,
                "turn": 1,
                "pinned_at": time.time(),
                "nagged": False,
            }
            save(key, state)
        elif state:
            state["turn"] = state.get("turn", 1) + 1
            save(key, state)

    if state:
        print(render_nag(state))
    prune_stale()
    return 0


def mode_stop(payload):
    key = session_key(payload)
    if payload.get("stop_hook_active"):
        return 0                      # already in a stop continuation — never re-block

    state = load(key)
    if not state:
        return 0

    if expired(state):
        clear(key)
        return 0

    if state.get("pure"):
        clear(key)                    # the question WAS the message; it got answered
        return 0

    if state.get("nagged"):
        return 0                      # one block per question, then it's advisory only

    state["nagged"] = True
    save(key, state)
    sys.stderr.write(
        "UNANSWERED QUESTION — you did the work but never answered this:\n"
        + "\n".join('  "%s"' % q for q in state["questions"])
        + "\nAnswer it now, plainly, then run: "
        "python3 ~/.claude/hooks/open-question.py --resolve\n"
    )
    return 2


def mode_show(payload):
    state = load(session_key(payload))
    if not state:
        print("No open question.")
        return 0
    age = int((time.time() - state.get("pinned_at", 0)) / 60)
    print("Open question (turn %d, %dm ago, %s):"
          % (state.get("turn", 1), age, "nagged" if state.get("nagged") else "not yet blocked"))
    for question in state["questions"]:
        print("  " + question)
    return 0


def main():
    args = sys.argv[1:]
    mode = args[0] if args else "--prompt"

    if mode == "--pin":
        text = " ".join(args[1:]).strip()
        payload = read_stdin_json()
        if not text:
            return 1
        if not text.endswith("?"):
            text += "?"
        save(session_key(payload), {
            "questions": [text],
            "pure": False,
            "turn": 1,
            "pinned_at": time.time(),
            "nagged": False,
        })
        print("Pinned: " + text)
        return 0

    payload = read_stdin_json()

    if mode in ("--resolve", "--clear"):
        clear(session_key(payload))
        print("Open question cleared.")
        return 0
    if mode == "--show":
        return mode_show(payload)
    if mode == "--stop":
        return mode_stop(payload)
    return mode_prompt(payload)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # A pinning hook must never be the reason a prompt or a stop fails.
        sys.exit(0)
