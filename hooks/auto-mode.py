#!/usr/bin/env python3
"""auto-mode.py — when auto is on, Claude decides instead of asking.

The problem: a session stops to ask the user a judgment question he has no basis to
answer ("magic link or password?"). The interruption costs more than a
reversible wrong pick would.

`/afk` banks such questions and refuses to act on them. `/carryon` stops dead.
Neither actually decides. This hook is the switch that makes it decide.

Five modes, wired in ~/.claude/settings.json plus the /auto skill:

  --gate    PreToolUse, matcher AskUserQuestion. Off: allow, print nothing.
            On: deny the call and hand the model the decision rule instead.
            Questions that look irreversible, outward-facing or money-shaped
            are allowed through untouched. So is a question asked again on a
            LATER turn, which is the model's escape hatch out of a wedge. The
            turn matters: a blocked model re-asking the identical question in
            the same breath is not insisting, it just did not absorb the
            answer, and letting that through defeated the whole gate.

  --stop    Stop. Off: silent. On: the turn ended, so push the model onto the
            next rung of the ladder instead of handing the session back. This
            is the half that was missing. The gate only ever saw questions,
            and measured against twelve real sessions the model almost never
            asked one: it wrote a status report and stopped, and the user typed
            "carry on" and "ok go" to restart it. Yields on an explicit
            STOPPED line, on a hard stop, once per turn, and at a cap.

  --prompt  UserPromptSubmit. ~50 tokens reminding the model auto is on, so it
            pre-empts rather than getting blocked mid-turn. Prints ABSOLUTELY
            NOTHING when auto is off: twelve of these already run per turn.
            Also counts turns, which is what --gate and --stop measure
            separation in: a turn boundary means the user has actually spoken.

  --on [away] / --off / --show   flip and inspect the switch.

State: ~/.claude/state/auto/<session>.json (+ .hud one-liner for the
statusline). Per session, so concurrent sessions do not bleed into each other,
and so the switch dies with the session rather than becoming a silent default.

Python not bash because the gate has to walk arbitrary nested JSON out of
tool_input, and because quotes and newlines in question text break the
sed-based JSON extraction the shell hooks use.

Disable: remove the auto-mode.py entries from ~/.claude/settings.json.
"""

import hashlib
import json
import os
import re
import sys
import time

STATE_DIR = os.path.join(
    os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude")),
    "state",
    "auto",
)

MAX_AGE_SECONDS = 8 * 3600   # a switch nobody turned off dies with the working day
PRUNE_AFTER_DAYS = 7
MAX_RECORDED = 40            # cap the decision list so state cannot grow unbounded

# How many times in a row --stop may push the model on before it yields.
# Low when the user is watching: he can see it happening and would rather it stop
# than grind. High in away mode, where stopping IS the failure.
PUSH_CAP_HERE = 3
PUSH_CAP_AWAY = 12

# Hard-stop matching at the end of a turn reads only the last stretch of text.
# A long status report mentions deploy, prod and credentials in passing while
# the actual next action is stated at the end. Matching the whole body made
# every substantial report look like a hard stop.
TAIL_CHARS = 600


# --- the rule the model gets handed ---------------------------------------

DECISION_RULE = (
    "auto is ON, so do not ask this. Decide it yourself: pick the reversible "
    "option, prefer the one that adds no new dependency, and prefer the "
    "conventional choice over the clever one. Say the pick and a one-clause "
    "reason in ONE line, then carry on with the work. "
    "If this really is irreversible, reaches another person, or spends money, "
    "ask the identical question once more and it will go through."
)

PROMPT_REMINDER = (
    "AUTO MODE ON. Do not use AskUserQuestion for judgment calls. Pick the "
    "reversible, conventional, dependency-free option, state the pick and a "
    "one-clause reason in one line, carry on. Anything irreversible, "
    "outward-facing or money-shaped still stops and asks."
)

# Handed back when the model ends a turn with the switch on. Deliberately the
# same ladder as section 3.2 of the /auto skill, compressed: the skill is the
# readable copy, this is the version that still fires at high context.
LADDER = (
    "auto is ON and you just ended the turn. Do not hand the session back yet. "
    "Walk this ladder and take the FIRST rung with a real candidate:\n"
    "  1. Broken beats new: failing build, typecheck, lint or test.\n"
    "  2. Unblock beats build: a person or a queued job is waiting.\n"
    "  3. Finish beats start: uncommitted diff, stub, TODO, test.skip.\n"
    "  4. Verify beats claim: something called done but never actually driven.\n"
    "  5. Ship beats polish: verified work unpushed, or a branch with no PR.\n"
    "  6. The next planned item from the plan, task list or handoff.\n"
    "Do not invent work. If you cannot name the rung an action came from, it is "
    "not an action.\n"
    "To stop instead, the whole ladder must be empty, or the next rung must be "
    "irreversible, reach another person, or spend money. Then end your reply "
    "with a line starting 'STOPPED:' and one clause saying what you need. That "
    "line is honoured immediately and never argued with."
)

# The model's way out. Anchored to the start of a line so it has to be a
# deliberate closing statement, not the word appearing mid-paragraph.
EXPLICIT_STOP = re.compile(
    r"^\s*(?:[*_`#>\-\s]*)(STOPPED|NEEDS YOU|BLOCKED ON YOU)\s*[:\-]",
    re.IGNORECASE | re.MULTILINE,
)


# --- what still reaches the user ----------------------------------------------

# Fire on their own. Biased towards false positives: being asked unnecessarily
# is an annoyance, guessing wrong on one of these is not recoverable.
DANGER = re.compile(
    r"\bdeploy(s|ing|ment)?\b"
    r"|\bproduction\b|\bprod\b"
    r"|force[ -]push"
    r"|\brm\s+-[rf]"
    r"|\bdrop\s+(table|database|column|schema)\b"
    r"|\btruncate\b"
    r"|\bmigrat(e|ion|ions)\b"
    r"|\bschema\s+change\b"
    r"|\bmerge\s+(in)?to\s+(main|master|trunk)\b"
    r"|dismiss\w*\s+.{0,30}review|changes[_ ]requested"
    r"|\birreversible\b|cannot\s+be\s+undone|\bpermanently\b"
    r"|\bcredential|\bsecret|\bapi[ -]?key\b|\.env\b"
    r"|\binvoice\b|\bpayment\b|\bsubscription\b|\bcharge\b"
    r"|[£$€]\s?\d",
    re.IGNORECASE,
)

# Need BOTH halves. "Should the error message say X or Y" is a judgment call;
# "should I send this message to a reviewer" is not.
OUTWARD_VERB = re.compile(
    r"\b(send|sending|email|emailing|dm|post|posting|publish|publishing"
    r"|reply|replying|notify|notifying|share|sharing|invite|inviting)\b",
    re.IGNORECASE,
)
OUTWARD_TARGET = re.compile(
    r"\b(slack|teams|customer|customers|client|clients|reviewer|stakeholder"
    r"|github|linkedin|twitter|public|publicly|externally|recipient"
    r"|to\s+(him|her|them|reviewer|lead|the user|the\s+team))\b",
    re.IGNORECASE,
)


def is_hard_stop(text):
    if DANGER.search(text):
        return True
    return bool(OUTWARD_VERB.search(text) and OUTWARD_TARGET.search(text))


# --- plumbing (shape lifted from open-question.py) -------------------------

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
    # the same UUID the hooks receive on stdin. That is what lets --on and --off,
    # run as plain shell commands from the skill, target this session's switch.
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
            state = json.load(handle)
    except Exception:
        return None
    if (time.time() - state.get("since", 0)) > MAX_AGE_SECONDS:
        clear(key)
        return None
    return state


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
    cutoff = time.time() - PRUNE_AFTER_DAYS * 86400
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
    count = len(state.get("decided", []))
    label = "auto away" if state.get("mode") == "away" else "auto"
    return "⚡ %s%s" % (label, (" ·%d" % count) if count else "")


# --- reading the question out of tool_input --------------------------------

def collect_strings(node, out, depth=0):
    """Walk whatever tool_input turns out to be and gather every string.

    The docs do not pin down the key names inside AskUserQuestion's tool_input,
    so match on the text rather than on a guessed path. Bounded depth so a
    pathological payload cannot spin.
    """
    if depth > 6:
        return
    if isinstance(node, str):
        out.append(node)
    elif isinstance(node, dict):
        for value in node.values():
            collect_strings(value, out, depth + 1)
    elif isinstance(node, list):
        for value in node:
            collect_strings(value, out, depth + 1)


def question_parts(payload):
    parts = []
    collect_strings(payload.get("tool_input"), parts)
    return parts


def fingerprint(text):
    normalised = re.sub(r"\s+", " ", text.strip().lower())
    return hashlib.sha1(normalised.encode("utf-8", "replace")).hexdigest()[:16]


def scrub(text):
    # The status list gets printed to a terminal, so drop control bytes before
    # they get there. Same reasoning as open-question.py's hud_line.
    text = re.sub(r"[\x00-\x08\x0b-\x1f\x7f]", "", text)
    return re.sub(r"\s+", " ", text).strip()


def headline(parts):
    """The question itself, for the status list.

    Take the first collected string containing a question mark rather than
    regexing across the joined text: a filename or a version number in the
    question body has a full stop in it and would chop the line in half.
    """
    for part in parts:
        if "?" in part:
            return scrub(part)[:160]
    return scrub(" ".join(parts))[:120]


# --- modes -----------------------------------------------------------------

def mode_gate(payload):
    key = session_key(payload)
    state = load(key)
    if not state or not state.get("on"):
        return 0                                  # switch off: change nothing

    parts = question_parts(payload)
    text = " ".join(parts)
    if not text.strip():
        return 0                                  # nothing to read, do not guess

    if is_hard_stop(text):
        return 0                                  # irreversible or outward: let it ask

    seen = state.setdefault("seen", {})
    mark = fingerprint(text)
    turn = state.get("turn", 1)
    first_asked = seen.get(mark)
    if first_asked is not None and first_asked < turn:
        # Asked again on a later turn, so the user has spoken since the block and
        # the model is genuinely insisting. Escape hatch, allow.
        del seen[mark]
        save(key, state)
        return 0

    seen[mark] = turn
    decided = state.setdefault("decided", [])
    decided.append(headline(parts))
    del decided[:-MAX_RECORDED]
    save(key, state)

    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": DECISION_RULE,
        }
    }))
    return 0


def transcript_tail(payload):
    """The text the model ended its turn with.

    Same reader as register-gate.py: content is a bare string on some entries
    and a list of blocks on others, and subagent output is not the session's
    own reply so it does not count.
    """
    path = payload.get("transcript_path") or ""
    if not path:
        return ""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return ""
    for raw in reversed(lines[-400:]):
        try:
            entry = json.loads(raw)
        except (ValueError, TypeError):
            continue
        if entry.get("isSidechain") or entry.get("type") != "assistant":
            continue
        content = (entry.get("message") or {}).get("content")
        if isinstance(content, str):
            blocks = [content]
        elif isinstance(content, list):
            blocks = [b.get("text", "") for b in content
                      if isinstance(b, dict) and b.get("type") == "text"]
        else:
            continue
        text = " ".join(b for b in blocks if b).strip()
        if text:
            return text
    return ""


def mode_stop(payload):
    key = session_key(payload)
    state = load(key)
    if not state or not state.get("on"):
        return 0                                  # switch off: change nothing

    text = transcript_tail(payload)
    if not text:
        return 0                                  # cannot read it, do not guess

    if EXPLICIT_STOP.search(text):
        # The model said it is done and why. Take it at its word, and clear the
        # budget so the next real turn starts with a full allowance.
        state["pushes"] = 0
        state.pop("last_push", None)
        save(key, state)
        return 0

    if is_hard_stop(text[-TAIL_CHARS:]):
        return 0                                  # irreversible or outward: let it stop

    # The budget IS the loop guard, which is why stop_hook_active is not an
    # unconditional pass here. It stays true for every stop in a continuation
    # chain, so honouring it would cap this at exactly one push per turn and
    # leave the original complaint intact. A counted budget that resets when
    # the user speaks bounds the loop without neutering it.
    cap = PUSH_CAP_AWAY if state.get("mode") == "away" else PUSH_CAP_HERE
    pushes = state.get("pushes", 0)
    if pushes >= cap:
        return 0                                  # budget spent, hand it back

    mark = fingerprint(text[-TAIL_CHARS:])
    if state.get("last_push") == mark:
        return 0                                  # ended identically twice: wedged

    state["pushes"] = pushes + 1
    state["last_push"] = mark
    try:
        save(key, state)
    except OSError:
        return 0                                  # cannot count it, so do not risk a loop
    sys.stderr.write(LADDER)
    return 2


def mode_prompt(payload):
    key = session_key(payload)
    state = load(key)
    if state and state.get("on"):
        # the user has spoken, so this is a new turn: the gate measures re-asks
        # against it, and the push allowance starts over.
        state["turn"] = state.get("turn", 1) + 1
        state["pushes"] = 0
        save(key, state)
        print(PROMPT_REMINDER)
    prune_stale()
    return 0


def mode_on(payload, args):
    key = session_key(payload)
    state = load(key) or {"decided": [], "seen": {}, "turn": 1, "pushes": 0}
    state.setdefault("turn", 1)
    state["pushes"] = 0
    state["on"] = True
    state["since"] = time.time()
    state["mode"] = "away" if any(a in ("away", "afk") for a in args) else "here"
    save(key, state)
    print("auto ON (%s). Judgment questions get decided, not asked." % state["mode"])
    return 0


def mode_off(payload):
    clear(session_key(payload))
    print("auto OFF. Judgment questions come back to you.")
    return 0


def mode_show(payload):
    state = load(session_key(payload))
    if not state or not state.get("on"):
        print("auto is OFF.")
        return 0
    mins = int((time.time() - state.get("since", 0)) / 60)
    decided = state.get("decided", [])
    cap = PUSH_CAP_AWAY if state.get("mode") == "away" else PUSH_CAP_HERE
    print("auto is ON (%s), %dm, %d decided, %d/%d carried on." % (
        state.get("mode", "here"), mins, len(decided), state.get("pushes", 0), cap))
    for item in decided[-10:]:
        print("  " + item)
    return 0


def main():
    args = sys.argv[1:]
    mode = args[0] if args else "--prompt"
    payload = read_stdin_json()

    if mode == "--gate":
        return mode_gate(payload)
    if mode == "--stop":
        return mode_stop(payload)
    if mode == "--on":
        return mode_on(payload, args[1:])
    if mode in ("--off", "--clear"):
        return mode_off(payload)
    if mode == "--show":
        return mode_show(payload)
    return mode_prompt(payload)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # A switch must never be the reason a prompt, a stop or a tool call fails.
        sys.exit(0)
