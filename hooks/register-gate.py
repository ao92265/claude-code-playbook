#!/usr/bin/env python3
"""register-gate.py — Stop hook. Blocks a turn that ends in a reply breaking REGISTER.

Why this exists
---------------
The REGISTER rules (plain English, no internals, status replies capped at 150 words,
overflow to a file, no em dashes) already fire on every prompt via answer-shape-nudge.sh.
They were still being ignored, for a structural reason: the caveman plugin injects AFTER
answer-shape on UserPromptSubmit and says "All technical substance stay." That is an
explicit licence to keep every jargon token, and it lands last. Prompt-side rules alone
cannot win that, and per the rules-must-be-hooks memory they decay further at depth.

So this is the enforcement half. Modelled on verify-gate.sh: exit 2 on stderr blocks the
stop and hands the model a correction. Transcript parsing follows stop-handoff.sh.

Two independent checks:

1. DASHES (rule 6). Binary, no judgement, so it blocks on a single hit. Em and en dashes
   are the top AI tell and the one thing the user notices every time. Checked outside fenced
   blocks and inline code, so quoting a filename or a string that contains one is fine.
   Not exempted by a depth request: rule 6 says "anywhere you write".

2. OVERLOAD (rules 1-3). Needs TWO signals at once, length AND jargon density, so a long
   plain-English answer passes and a two-line technical answer passes. Only the actual
   failure mode, a wall of symbol names, paths, test counts and exit codes, trips it.

Length has two ceilings, not one. Over SOFT_WORD_LIMIT leaves a one-line nudge that the
--prompt entry point (registered on UserPromptSubmit) spends on the next turn; over
HARD_WORD_LIMIT still blocks. A Stop hook cannot talk to the model directly, so the warn
has to be deferred a turn. That buys back the regenerate on a near-miss, which was most of
what this gate was actually costing.

Every evaluation is logged to ~/.claude/register-gate.log with the scores, so thresholds
get tuned against real traffic instead of guessed. If overload fires on most turns, raise
WORD_LIMIT; do not disable the gate.

Disable: add `register-gate` to CLAUDE_SKIP_HOOKS, or remove the entry from settings.json.
"""

import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path

WORD_LIMIT = 80        # REGISTER rule 3's own cap
INTERNALS_LIMIT = 3    # distinct technical references tolerated in a status reply
MAX_BLOCKS_PER_TURN = 2  # after this many blocks in one turn chain, stand down

# Soft ceiling once the user has asked for a tldr in this session. The tldr skill registers
# tldr-mode.py from its frontmatter, which drops a marker here; "tldr" means stay
# short for the session, not for one reply. Over this warns; the hard block is still
# HARD_WORD_LIMIT.
TLDR_WORD_LIMIT = 40

# Length ceiling that bites on its own, with no jargon required.
# Added 2026-08-21. The overload check below needs length AND jargon together, so a
# 400-word wall of plain English sailed through it every time. That is the reply
# the user actually drowns in, and asking for brevity in prompt text stopped working as
# context grew. Set high enough that a genuine multi-part answer fits and only a wall
# trips it. Raise it rather than disabling the gate.
# Lowered 320 to 150 on 21 Aug 2026 at the user's call, after measuring his live sessions:
# replies clustered between 100 and 320 words, so 320 caught almost nothing. 150 is the
# number REGISTER rule 3 already asks for, so the gate and the written rule now agree.
#
# Split into a warn band and a block ceiling on 21 Aug 2026, measured over the 90 minutes
# that followed the 320-to-150 drop: 202 real turn-endings, 11 blocked (1 in 20), 10 of
# them on length alone. Six of those ten landed between 160 and 227 words, a handful over
# the line rather than a wall; only three (323, 332, 397) were the failure mode this gate
# exists for. Live reply lengths ran p50=118, p90=204. Each block burns a whole reply that
# is generated, thrown away and regenerated, so paying that for a 160-word answer is a bad
# trade. Now: over SOFT warns on the next prompt (costs nothing), over HARD still blocks.
# Lowered again 24 Aug 2026 at the user's call ("right now the length is the problem").
# Measured over 1240 logged replies at the time: p50=104, p75=178, p90=242, p95=294.
# The old soft ceiling of 150 sat above the median, so most replies never got nudged.
# Now soft=80 (free nudge, catches roughly the top 60%) and hard=200 (blocks roughly
# the top 15%, up from about 10%). Hard was NOT dropped to 80: each block throws away a
# whole generated reply, and blocking a third of all turns is a worse trade than nudging.
# Re-measured 9 Sep 2026, after the gate had been unregistered for 13 days and the user
# showed a screenshot of six live panes all walls of text. 2,235 replies over 3 days,
# prose words only: p50=25, p75=72, p90=174, p95=230, max=406. Concise had fixed the
# median; the tail was untouched. Over 40 words: 34%. Over 80: 22%. Over 200: 7%.
# Over 250: 4%. Soft stays 80 (nudge the real over-runs, stay clear of a 40-word near
# miss so it does not become wallpaper). Hard 200 to 250, past his own p95, so a block
# costs a doubled message only on a true wall. A Stop hook cannot un-print the reply it
# blocks, so every block puts a SECOND message on his screen: that is why the cheap
# warn does the daily work and the block is reserved for the top few percent.
SOFT_WORD_LIMIT = 80
HARD_WORD_LIMIT = 250

# Block ceiling once "tldr" has latched for the session. Was HARD_WORD_LIMIT, which meant
# asking for a tldr lowered the free nudge but left the block where it was for everyone.
# Retuned 9 Sep 2026 alongside the thresholds below.
TLDR_HARD_LIMIT = 150

# Ceiling when the prompt genuinely asked to go deep. Added 2026-08-21 after 24 turns in
# one day sailed through with the gate fully switched off. A depth request means "more
# detail is welcome", not "length no longer applies", so it now raises the ceiling rather
# than removing it. The jargon check below is still waived outright for these.
# No warn band here: a depth request already means length is welcome, so nudging about it
# would just be noise.
DEPTH_WORD_LIMIT = 700

LOG = Path.home() / ".claude" / "register-gate.log"
STATE = Path.home() / ".claude" / "state" / "register-gate"
DETAIL_DIR = Path.home() / ".claude" / "detail"

# Phrases that mean "go deep, I want the internals". REGISTER rule 5 exempts these
# from the overload check. It does NOT exempt them from the dash check.
DEPTH_REQUEST = re.compile(
    r"\b(explain|walk me through|how does|how do you|why does|why did|in detail|deep dive|"
    r"deep-dive|review|debug|root cause|root-cause|technical|verbose|show me the|"
    r"full detail|more detail|elaborate)\b",
    re.I,
)

# Each pattern counts DISTINCT matches, so one repeated flag cannot inflate the score.
INTERNALS = [
    ("path", r"(?:^|\s)[~./][\w./-]*/[\w.-]+"),
    ("file", r"\b[\w-]+\.(?:ts|tsx|js|jsx|mjs|py|sh|md|json|cs|go|rs|ya?ml|sql|css|html)\b"),
    ("symbol", r"\b[A-Za-z_]\w*\.[A-Za-z_]\w*\.[A-Za-z_]\w*\b"),
    ("lineref", r"\b[\w./-]+:\d+\b"),
    ("exitcode", r"\bexit(?:\s+code)?\s+\d+\b"),
    ("testcount", r"\b\d+\s+(?:passed|failed|failing|tests?|errors?|warnings?)\b"),
    ("branch", r"\b(?:feat|fix|chore|refactor|docs|test|spike)/[\w.-]+"),
    ("flag", r"(?:^|\s)--[a-z][\w-]+"),
    ("command", r"\b(?:npm|npx|git|gh|dotnet|pytest|cargo|tsc|pnpm|yarn|make|docker)\s+[a-z][\w:-]*"),
]

FENCE = re.compile(r"```.*?```", re.S)
INLINE_CODE = re.compile(r"`[^`\n]*`")
DASH = re.compile(r"[—–]")


def log(line: str) -> None:
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a") as fh:
            fh.write(f"{time.strftime('%F %T')} {line}\n")
    except OSError:
        pass


def passthrough(reason: str, detail: str = "", session: str = "?") -> None:
    # Session id on EVERY line, pass or block. Without it, a quiet pass in one pane
    # is indistinguishable from a block in another when several sessions are live,
    # which is exactly the confusion that cost time on 10 Aug.
    # Flattened: a multi-line prompt snippet used to push "session=" onto its own
    # physical line, which made a day of traffic unreadable when it mattered.
    flat = " ".join(f"PASS {reason} {detail} session={session}".split())
    log(flat)
    sys.exit(0)


# Text that arrives as a "user" entry but that the user never typed. Reviewed 21 Aug 2026
# against 2,238 logged evaluations: 165 of the 344 depth exemptions came from these,
# because a skill body or a teammate message almost always contains "review", "debug"
# or "in detail", which matched DEPTH_REQUEST and switched the overload check off.
NOT_ALEX = (
    "Another Claude session sent a message:",
    "Base directory for this skill:",
    "Stop hook feedback:",
    "[SYSTEM NOTIFICATION",
    "<task-notification>",
    "<local-command-caveat>",
    "<command-name>",
)


# An injected skill or slash-command body opens with its own markdown heading, e.g.
# "# /loop - schedule a recurring or self-paced prompt". Added 2026-08-21: the /loop body
# alone accounted for 24 depth exemptions in one day across two live sessions, because it
# contains the word "prompt" and reads to the gate as if the user had asked to go deep.
SKILL_HEADING = re.compile(r"#\s*/[a-z][\w-]*\b")


def typed_by_alex(text: str) -> bool:
    """False for injected user-role text: skill bodies, teammate posts, hook feedback."""
    head = text.lstrip()[:200]
    if SKILL_HEADING.match(head):
        return False
    return not any(marker in head for marker in NOT_ALEX)


def read_transcript(path: str):
    """Return (last assistant text, last real user prompt, entrypoint). Sidechains excluded.

    The entrypoint says whether a human is reading this. Headless runs (afk supervisors,
    the control tower, anything driving the SDK) never see the reply rules and their
    "replies" are machine-to-machine instructions, so gating them is pure waste: measured
    9 Sep 2026, 79 percent of sdk-py turns carry an em dash against 3.6 percent of real
    interactive ones. Same filter rule-drift.py already applies when scoring compliance.
    """
    assistant, user, entrypoint = "", "", ""
    try:
        lines = Path(path).read_text(errors="replace").splitlines()
    except OSError:
        return assistant, user

    # Window raised from 400 in review, 21 Aug 2026. A tool-heavy turn pushed the last
    # thing the user typed outside it, so the prompt came back empty and a genuine request
    # to go deep could not exempt the long answer that followed it.
    for raw in reversed(lines[-2000:]):
        if assistant and user:
            break
        try:
            entry = json.loads(raw)
        except (ValueError, TypeError):
            continue
        # Subagent output is not a reply to the user, so it is not this gate's business.
        if entry.get("isSidechain"):
            continue
        content = (entry.get("message") or {}).get("content")
        if isinstance(content, str):
            blocks = [content]
        elif isinstance(content, list):
            blocks = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
        else:
            continue
        text = " ".join(b for b in blocks if b).strip()
        if not text:
            continue
        if entry.get("type") == "assistant" and not assistant:
            assistant = text
            entrypoint = str(entry.get("entrypoint") or "")
        elif entry.get("type") == "user" and not user:
            # Injected blocks are not things the user typed.
            if "<system-reminder>" in text or text.startswith("<") or "Caveat:" in text:
                continue
            if not typed_by_alex(text):
                continue
            user = text
    return assistant, user, entrypoint


def tldr_active(session: str, transcript: str) -> bool:
    """True while an earlier "tldr" in this session still stands.

    `/clear` keeps the same session id, so the marker alone would carry a tldr from a
    finished task into an unrelated one. Drop it when the transcript shows a clear that
    happened after the latch. Found in review, 21 Aug 2026.
    """
    marker = STATE / f"{session}.tldr"
    if not marker.is_file():
        return False
    try:
        latched_at = marker.read_text().strip()
    except OSError:
        return False

    try:
        for raw in reversed(Path(transcript).read_text(errors="replace").splitlines()[-800:]):
            try:
                entry = json.loads(raw)
            except (ValueError, TypeError):
                continue
            stamp = entry.get("timestamp") or ""
            if not stamp:
                continue
            if stamp <= latched_at:
                break          # entries are chronological, so nothing later remains
            content = (entry.get("message") or {}).get("content")
            text = content if isinstance(content, str) else ""
            if "<command-name>/clear" in text or text.strip() == "/clear":
                marker.unlink(missing_ok=True)
                return False
    except OSError:
        pass
    return True


def streak(session: str) -> int:
    """How many times this gate has blocked the current turn chain."""
    try:
        return int((STATE / f"{session}.streak").read_text().strip() or 0)
    except (OSError, ValueError):
        return 0


def set_streak(session: str, value: int) -> None:
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        f = STATE / f"{session}.streak"
        if value <= 0:
            f.unlink(missing_ok=True)
        else:
            f.write_text(str(value))
    except OSError:
        pass


def warn(session: str, words: int, ceiling: int) -> None:
    """Leave a one-line nudge for the NEXT prompt instead of blocking this turn.

    A Stop hook has no channel back into context: exit 0 stdout lands in the transcript,
    not in the model's input. So an over-soft reply is recorded here and spent by the
    --prompt entry point on the following turn. The over-long reply still lands once,
    which is the price of not burning a regenerate on a near-miss.
    """
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        (STATE / f"{session}.warn").write_text(
            f"REGISTER: your last reply was {words} words against a {ceiling} ceiling. "
            f"Tighten this one."
        )
    except OSError:
        pass


def block(session: str, reply: str, message: str, log_line: str) -> None:
    """Write the loop marker, log, emit the correction, block the stop."""
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        (STATE / f"{session}.last").write_text(hashlib.sha1(reply.encode()).hexdigest())
    except OSError:
        pass
    (STATE / f"{session}.warn").unlink(missing_ok=True)
    set_streak(session, streak(session) + 1)
    log(log_line)
    sys.stderr.write(message)
    sys.exit(2)


def prompt_mode() -> None:
    """UserPromptSubmit entry point. Spends a warn marker left by the Stop path.

    Delete-on-read is the point: a marker that survives repeats the same nudge every turn
    and becomes wallpaper, which is how prompt-side rules stop firing in the first place.
    No marker means print nothing, so the common case costs zero tokens.
    """
    try:
        payload = json.load(sys.stdin)
    except (ValueError, TypeError):
        sys.exit(0)
    session = str(payload.get("session_id") or "unknown")
    marker = STATE / f"{session}.warn"
    try:
        note = marker.read_text().strip()
    except OSError:
        sys.exit(0)
    marker.unlink(missing_ok=True)
    if note:
        print(note)
    sys.exit(0)


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except (ValueError, TypeError):
        sys.exit(0)

    # Exact token match. A bare substring test meant an unrelated value such as
    # "no-register-gate-v2" silently disabled the gate. Found in review, 21 Aug 2026.
    skip = (os.environ.get("CLAUDE_SKIP_HOOKS", "") + ","
            + os.environ.get("OMC_SKIP_HOOKS", ""))
    if "register-gate" in {t.strip() for t in skip.split(",")}:
        sys.exit(0)

    # OpenAlice trading workspaces are exempt (25 Aug 2026). Its agent pulled three
    # crypto prices then answered in one sentence with none of them in it: the word
    # ceiling here plus caveman ate the deliverable. Those sessions are Alice talking
    # to the user through a different surface, not a status reply in this transcript.
    # Scoped to ~/.openalice, so every other directory is gated exactly as before.
    cwd = str(payload.get("cwd") or "")
    openalice = str(Path.home() / ".openalice")
    if cwd == openalice or cwd.startswith(openalice + os.sep):
        sys.exit(0)

    session = str(payload.get("session_id") or "unknown")

    # Loop guard. `stop_hook_active` is set whenever ANY Stop hook blocked the turn, not
    # just this one, and verify-gate and review-gate block often. Reviewed 21 Aug 2026:
    # 730 of 2,238 evaluations exited here, so the gate was switching itself off on a
    # third of all turns, against 69 blocks it ever made. Now it only stands down after
    # this gate itself has blocked the same turn chain twice, which bounds a loop
    # without surrendering the coverage.
    if payload.get("stop_hook_active") and streak(session) >= MAX_BLOCKS_PER_TURN:
        passthrough("loop-guard", f"streak={streak(session)}", session=session)

    transcript = payload.get("transcript_path") or ""
    if not transcript or not Path(transcript).is_file():
        passthrough("no-transcript", session=session)

    reply, prompt, entrypoint = read_transcript(transcript)
    if not reply:
        passthrough("no-text-reply", session=session)

    # Only gate replies a human is actually reading. Anything but the interactive CLI is
    # a headless run whose "reply" is machine-to-machine text; blocking those burns a
    # regenerate on every turn and can derail an unattended job. Empty means an older
    # record with no entrypoint field, which is treated as interactive.
    if entrypoint and entrypoint != "cli":
        passthrough("not-interactive", f"entrypoint={entrypoint}", session=session)

    # Second loop guard, keyed on the reply itself rather than a timer: if this exact
    # text already blocked, the model is stuck, so let it through. A timer would leave
    # a window where fast successive turns skipped the gate entirely.
    try:
        marker = STATE / f"{session}.last"
        if marker.is_file() and marker.read_text().strip() == hashlib.sha1(reply.encode()).hexdigest():
            passthrough("already-blocked-this-text", session=session)
    except OSError:
        pass

    prose = FENCE.sub(" ", reply)

    # --- check 1: dashes (rule 6). Binary, blocks on one hit, no depth exemption. ---
    dash_text = INLINE_CODE.sub(" ", prose)
    hits = list(DASH.finditer(dash_text))
    if hits:
        samples = []
        for m in hits[:2]:
            start, end = max(0, m.start() - 35), min(len(dash_text), m.end() + 35)
            samples.append("..." + " ".join(dash_text[start:end].split()) + "...")
        shown = "\n".join(f"   {s}" for s in samples)
        block(
            session, reply,
            f"REGISTER rule 6: your last reply contains {len(hits)} em/en dash(es).\n"
            f"{shown}\n"
            f"This is the top AI tell and the one thing the user notices every time.\n"
            f"Resend the reply with every one replaced by a full stop, a comma, a colon or "
            f"brackets. Change nothing else about it.\n",
            f"BLOCK dashes={len(hits)} session={session}",
        )

    # --- check 2: overload (rules 1-3). Needs length AND jargon density together. ---
    depth = bool(DEPTH_REQUEST.search(prompt or ""))

    total_words = len(reply.split())
    words = len(prose.split())
    ratio = (words / total_words) if total_words else 1.0

    # Mostly a code block, a diff or a commit body. Those are allowed to be technical.
    if ratio < 0.4:
        passthrough("mostly-code", f"ratio={ratio:.2f}", session=session)

    # --- check 2a: sheer length. Blocks on its own, no jargon needed. ---
    tldr_latched = tldr_active(session, transcript)
    if tldr_latched:
        soft, ceiling = TLDR_WORD_LIMIT, TLDR_HARD_LIMIT
    elif depth:
        soft, ceiling = None, DEPTH_WORD_LIMIT
    else:
        soft, ceiling = SOFT_WORD_LIMIT, HARD_WORD_LIMIT
    if soft is not None and soft < words <= ceiling:
        # Over the written rule but not a wall. Nudge next turn, do not throw this reply
        # away. Falls through on purpose: a reply that is both wordy AND jargon-heavy can
        # still block on the internals check below.
        warn(session, words, soft)
        log(f"NOTE over-soft words={words} soft={soft} session={session}")
    if words > ceiling:
        long_detail = DETAIL_DIR / f"{session[:8]}-{int(time.time())}-long.md"
        if tldr_latched:
            because = ("you asked for a tldr earlier in this session, which stands until "
                       "the session ends")
        elif depth:
            because = "that is the ceiling even when you have asked to go deep"
        else:
            because = (f"there was no request to go deep. REGISTER rule 3 asks for "
                       f"{SOFT_WORD_LIMIT}; this is well past a near-miss")
        block(
            session, reply,
            f"REGISTER: that reply was {words} words. The ceiling is {ceiling} and "
            f"{because}.\n"
            f"the user reads these on a phone between other things. A wall of text is the "
            f"failure, even when every sentence in it is correct.\n"
            f"1. Move everything that is not the answer into {long_detail}.\n"
            f"2. Resend at most: the answer or what changed, anything he has to decide, "
            f"what happens next, and the path to that file.\n"
            f"Keep his own words for the scope. Do not add a recap or a closing line.\n",
            f"BLOCK long words={words} session={session}",
        )

    # Count distinct SPANS, not distinct per-pattern matches. A single reference such as
    # a path with a line number matches path, file and lineref at once, which on its own
    # hit the limit of 3 and blocked an otherwise fine reply. Found in review, 21 Aug 2026.
    spans = []
    for _name, pattern in INTERNALS:
        for m in re.finditer(pattern, prose, re.M):
            if not m.group(0).strip():
                continue
            if any(m.start() < end and start < m.end() for start, end in spans):
                continue
            spans.append((m.start(), m.end()))
    internals = len({prose[s:e].strip() for s, e in spans})

    if depth:
        set_streak(session, 0)
        passthrough("depth-requested", f'prompt="{prompt[:60]}"', session=session)

    if words <= WORD_LIMIT or internals < INTERNALS_LIMIT:
        set_streak(session, 0)   # this turn chain ended cleanly
        passthrough("ok", f"words={words} internals={internals}", session=session)

    detail_path = DETAIL_DIR / f"{session[:8]}-{int(time.time())}.md"
    block(
        session, reply,
        f"REGISTER: that reply was {words} words with {internals} technical references "
        f"(caps are {WORD_LIMIT} words and {INTERNALS_LIMIT}).\n"
        f"Do not resend it shorter. Cut the jargon, not just the length.\n"
        f"1. Write the full technical detail to your scratchpad, or to {detail_path}.\n"
        f"2. Replace the reply with exactly four lines:\n"
        f"   - what changed, in plain English, no symbol names or file paths\n"
        f"   - what the user decides, if anything\n"
        f"   - what happens next\n"
        f"   - the path to the detail file\n"
        f"Nothing else. No headers, no bullets beyond those, no recap.\n",
        f"BLOCK words={words} internals={internals} session={session}",
    )


if __name__ == "__main__":
    if "--prompt" in sys.argv[1:]:
        prompt_mode()
    main()
