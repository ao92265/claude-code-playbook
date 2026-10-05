#!/bin/bash
# verify-gate.sh — Stop hook + baseline arming.
#
# Modes:
#   --arm       : capture current tsc error count as baseline, set flag, exit 0.
#                 Run this BEFORE starting work on a task.
#   --auto-arm  : PreToolUse(Edit|Write) mode. Reads tool_input JSON from stdin.
#                 If edited file is code + in a JS/TS repo + not already armed,
#                 capture baseline in the BACKGROUND (non-blocking) and set flag.
#                 Always exit 0 — never blocks an edit. Closes the loop so the
#                 Stop gate fires automatically without a manual --arm.
#   (none)      : Stop-hook mode. If flag exists, compare current state vs baseline.
#                 Block stop (exit 2) only if errors REGRESSED from baseline.
#                 Flag absent → exit 0 (no-op).
#
# Files (under repo's .claude/state/):
#   needs-verify       — empty marker
#   verify-baseline    — `tsc_errors=<N>` snapshot at arm time
#   verify-gate.log    — output log

set -u

find_repo() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/package.json" ] || [ -d "$dir/.git" ]; then
      echo "$dir"; return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

find_flag_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/.claude/state/needs-verify" ] && { echo "$dir"; return 0; }
    dir=$(dirname "$dir")
  done
  return 1
}

count_tsc_errors() {
  local repo="$1"
  cd "$repo" || return 0
  [ -f tsconfig.json ] || { echo 0; return; }
  local out
  if grep -q '"build"' package.json 2>/dev/null && grep -q 'tsc -b\|tsc --build' package.json 2>/dev/null; then
    out=$(npx --no-install tsc -b 2>&1 || true)
  else
    out=$(npx --no-install tsc --noEmit 2>&1 || true)
  fi
  echo "$out" | grep -cE 'error TS[0-9]+'
}

# --- auto-arm mode (PreToolUse Edit|Write) ---
# Reads tool_input JSON from stdin. Non-blocking: always exits 0.
if [ "${1:-}" = "--auto-arm" ]; then
  INPUT=$(cat)
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  [ -z "$FILE_PATH" ] && exit 0

  # Only arm for source files (skip docs/config/state churn).
  case "$FILE_PATH" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.vue|*.svelte) ;;
    *) exit 0 ;;
  esac

  REPO=$(find_repo) || exit 0
  [ -f "$REPO/package.json" ] || exit 0          # JS/TS repos only
  [ -f "$REPO/.claude/state/needs-verify" ] && exit 0   # already armed this session

  # Capture baseline in background so the edit is never delayed. PreToolUse
  # fires before the edit lands, so the baseline reflects pre-edit state.
  mkdir -p "$REPO/.claude/state"
  touch "$REPO/.claude/state/needs-verify"       # set flag immediately (race-free arm)
  ( N=$(count_tsc_errors "$REPO"); echo "tsc_errors=$N" > "$REPO/.claude/state/verify-baseline" ) >/dev/null 2>&1 &
  exit 0
fi

# --- arm mode ---
if [ "${1:-}" = "--arm" ]; then
  REPO=$(find_repo) || { echo "verify-gate: no repo found from $PWD" >&2; exit 1; }
  mkdir -p "$REPO/.claude/state"
  echo "[verify-gate] arming baseline in $REPO..." >&2
  N=$(count_tsc_errors "$REPO")
  echo "tsc_errors=$N" > "$REPO/.claude/state/verify-baseline"
  touch "$REPO/.claude/state/needs-verify"
  echo "verify-gate: armed. baseline tsc errors=$N. Flag set at $REPO/.claude/state/needs-verify" >&2
  exit 0
fi

# --- Stop hook mode ---
# Read the stop payload once, up front. The review gate below is the only thing
# in this mode that wants it, and stdin can only be drained once.
STOP_PAYLOAD=""
[ -t 0 ] || STOP_PAYLOAD=$(cat 2>/dev/null || true)

# Review gate. Language agnostic, unlike the tsc half further down, and it runs
# first for that reason. Enforces the one rule nothing else enforced: writing and
# reviewing are separate passes. 2+ source files edited this session with nothing
# having reviewed them blocks the stop ONCE, then yields, so it can never trap a
# session. Fail-open at every step: no payload, no transcript, unreadable
# transcript or a python that errors all mean pass.
if [ -n "$STOP_PAYLOAD" ]; then
  # The payload travels in the environment, not on stdin: the heredoc below is
  # already using stdin to feed python the program itself.
  RG_VERDICT=$(RG_PAYLOAD="$STOP_PAYLOAD" python3 - <<'RGPY' 2>/dev/null || echo PASS
import json, os, re, time
from collections import deque
from pathlib import Path

REVIEWERS = {"code-reviewer", "security-reviewer", "verifier", "critic"}
EDITORS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
SOURCE = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".svelte", ".py",
          ".sh", ".bash", ".zsh", ".rb", ".go", ".rs", ".cs", ".java", ".kt",
          ".swift", ".sql", ".php", ".c", ".cc", ".cpp", ".h", ".hpp", ".m",
          ".scala", ".ex", ".exs")
# Prose and machine state. Editing a plan, a memory or a scratch file is not the
# kind of work that needs a second pair of eyes.
SKIP = ("/.claude/plans/", "/.claude/state/", "/.claude/projects/", "/scratchpad/",
        "/.omc/", "/node_modules/")
# The machine's temp roots earn their place: writing a probe script there is what
# a reviewer does, and counting it made the review look like fresh unreviewed
# work. Matched as a PREFIX, not a substring, or a repo with its own tmp/ folder
# would go dark: /Users/x/Repos/app/src/tmp/helper.ts is real work.
SKIP_ROOTS = ("/tmp/", "/private/tmp/", "/var/folders/")
LOG = Path.home() / ".claude" / "review-gate.log"
MARKS = Path.home() / ".claude" / "state" / "review-gate"
MARK_TTL = 14 * 86400


def log(line: str) -> None:
    # Same house rule as register-gate.py: every pass and every block leaves a
    # trace with the session on it, or a wrong call is invisible afterwards.
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a") as fh:
            fh.write(f"{time.strftime('%F %T')} {line}\n")
    except OSError:
        pass


# Shell writes: a redirect, a tee or an in-place sed. Under bypass permissions
# the agent is told to prefer Bash over the Edit tool, so without this the gate
# is blind to most of a session's real edits. Reads (cat, grep, sed without -i)
# deliberately do not match.
# A '>' preceded by '-' or '=' is an arrow in prose, not a redirect.
REDIRECT = re.compile(r"(?<![-=])(?:>>?|\btee\s+(?:-a\s+)?)\s*([\"']?)([^\s;|&()\"']+)\1")
# Only the run of arguments belonging to this sed, not the rest of the command.
# Sweeping the whole string counted every path inside a heredoc that merely
# quoted a sed example, which is how this gate first over-reported on itself.
SED_IN_PLACE = re.compile(r"\bsed\s+-i\b([^;|&\n]*)")
# Heredoc bodies are data, not commands. A redirect quoted inside one is text.
HEREDOC = re.compile(r"<<-?\s*([\"']?)(\w+)\1.*?^\2$", re.S | re.M)
# The directory a relative write lands in, when the command says so itself.
CD_PREFIX = re.compile(r"\bcd\s+([\"']?)(/[^\s;|&()\"']+)\1")
TOKEN = re.compile(r"[^\s;|&()\"']+")
# Backtick by code point: a literal one here would end the shell heredoc early.
SHELL_META = "$%*{}" + chr(96)


def shell_targets(command: str):
    """Files a shell command writes to. Redirect and tee name an exact target.
    'sed -i' does not, because its flag takes an optional suffix argument that
    cannot be told from a filename, so every source-looking token in that one
    command segment counts.

    Nothing carrying a shell metacharacter, because command text is full of
    things shaped like filenames that are not files: '%s/eps.ts' from a printf
    template, '$S/bad.ts' from an unexpanded variable. Counting those is how
    this gate once reported 12 changed files on a session that changed one.

    A relative target is kept only when the same command says where it lands
    ('cd /repo && cat > src/x.ts', which is the common shape). The anchor is the
    LAST cd before that particular write, not the first in the string: 'cd /tmp
    && ls; cd /repo && cat > src/a.ts' belongs to /repo, and filing it under
    /tmp would invent a path that does not exist. With no cd before it at all,
    the directory is unknowable from here and the write is dropped."""
    body = HEREDOC.sub(" ", command)
    found = [(m.start(), m.group(2)) for m in REDIRECT.finditer(body)]
    for m in SED_IN_PLACE.finditer(body):
        found.extend((m.start(), t) for t in TOKEN.findall(m.group(1)))
    cds = [(m.start(), m.group(2)) for m in CD_PREFIX.finditer(body)]
    resolved = []
    for offset, target in found:
        if any(c in target for c in SHELL_META):
            continue
        if target.startswith("/"):
            resolved.append(os.path.normpath(target))
            continue
        anchor = [d for pos, d in cds if pos < offset]
        if anchor:
            resolved.append(os.path.normpath(anchor[-1].rstrip("/") + "/" + target))
    return resolved


def qualifies(data: dict) -> str:
    path = str(data.get("file_path") or data.get("notebook_path") or "")
    if (path.endswith(SOURCE) and not path.startswith(SKIP_ROOTS)
            and not any(s in path for s in SKIP)):
        return path
    return ""


def scan(lines, edited: set):
    """Walk transcript lines once. Returns (last_edit, last_review) as ISO
    timestamps, empty string when the thing never happened.

    Ordering is by timestamp, not line number. Line numbers cannot order a
    delegated edit against a review, because the subagent writes a separate file
    with its own numbering, and the fields that supposedly link the two do not:
    measured on 425 real subagent transcripts, sourceToolAssistantUUID is
    present on 418 and resolves into the parent transcript on none of them.
    Timestamps are on every entry that carries a tool call (607 of 607 sampled).

    Ordering is what makes 'a reviewer ran BEFORE the edits' fail to count: a
    /done run early in a session spawns 'verifier', and without ordering that
    would exempt every edit made afterwards."""
    last_edit = last_review = ""
    for raw in lines:
        try:
            entry = json.loads(raw)
        except (ValueError, TypeError):
            continue
        i = str(entry.get("timestamp") or "")
        content = (entry.get("message") or {}).get("content")
        if isinstance(content, str):
            # Slash commands arrive as user text, so this is where /code-review
            # and /pr-review show up. The tag plus the user type is the check:
            # the bare word appears whenever the command is merely discussed.
            if entry.get("type") == "user" and (
                "<command-name>/code-review" in content
                or "<command-name>/pr-review" in content
            ):
                last_review = max(last_review, i)
            continue
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            name = block.get("name")
            data = block.get("input") or {}
            if not isinstance(data, dict):
                continue
            if name in EDITORS:
                path = qualifies(data)
                if path:
                    edited.add(path)
                    last_edit = max(last_edit, i)
            elif name == "Bash":
                for target in shell_targets(str(data.get("command") or "")):
                    if qualifies({"file_path": target}):
                        edited.add(target)
                        last_edit = max(last_edit, i)
            elif name == "Agent":
                if str(data.get("subagent_type") or "") in REVIEWERS:
                    last_review = max(last_review, i)
            elif name == "Skill" and "requesting-code-review" in str(data.get("skill") or ""):
                last_review = max(last_review, i)
            elif name == "ReportFindings":
                last_review = max(last_review, i)
    return last_edit, last_review


def subagent_edits(transcript: str, edited: set):
    """Subagent edits never appear in the main transcript, they get their own
    file. Without this the gate is inert exactly when it matters most, because
    multi-file work is the work that gets delegated.

    Returns the timestamp of the last edit each contributing subagent made. An
    agent that only read returns nothing, so a read-only Explore launched after
    a review cannot re-arm the gate on work that was already reviewed."""
    stamps = []
    try:
        folder = Path(str(transcript)[:-6] if str(transcript).endswith(".jsonl") else transcript)
        folder = folder / "subagents"
        # By mtime, so the 40-file cap drops the oldest rather than an
        # alphabetical slice of agent-<slug>-<hash>.jsonl.
        files = sorted(folder.glob("*.jsonl"), key=lambda f: f.stat().st_mtime)[-40:]
    except OSError:
        return stamps
    for path in files:
        try:
            # Streamed whole, not windowed. A long delegated run is exactly the
            # case worth catching, and a bounded window would drop its early
            # edits, or all of them, and report nothing.
            with path.open(errors="replace") as fh:
                edit_ts, _ = scan(fh, edited)
        except OSError:
            continue
        # Always append. Gating this on the file SET growing was a live false
        # negative: 'review, then delegate the fix on those same files' adds no
        # new paths, so it contributed no timestamp and the stale review still
        # counted. An agent that only read returns an empty timestamp, which
        # loses every comparison, so there is nothing to guard against.
        stamps.append(edit_ts)
    return stamps


def prune() -> None:
    cutoff = time.time() - MARK_TTL
    try:
        for old in MARKS.glob("*.blocked"):
            if old.stat().st_mtime < cutoff:
                old.unlink()
    except OSError:
        pass


def main() -> str:
    payload = json.loads(os.environ.get("RG_PAYLOAD") or "{}")
    if payload.get("stop_hook_active"):
        return "PASS already-blocked-this-turn"
    session = str(payload.get("session_id") or "").strip()
    transcript = payload.get("transcript_path") or ""
    if not session or not transcript:
        return "PASS no-session-or-transcript"
    mark = MARKS / f"{session}.blocked"
    if mark.exists():
        return "PASS blocked-once-already"
    try:
        with open(transcript, errors="replace") as fh:
            lines = deque(fh, maxlen=4000)
    except OSError:
        return "PASS transcript-unreadable"

    edited: set = set()
    last_edit, last_review = scan(lines, edited)
    for stamp in subagent_edits(transcript, edited):
        # Delegated edits count from when they happened, so a review still has
        # to come after the work, and only after work that actually happened.
        last_edit = max(last_edit, stamp)

    if len(edited) < 2:
        return f"PASS files={len(edited)}"
    if last_review and last_review > last_edit:
        return f"PASS reviewed-after-edits files={len(edited)}"
    try:
        prune()
        MARKS.mkdir(parents=True, exist_ok=True)
        mark.write_text("\n".join(sorted(edited)))
    except OSError:
        return "PASS marker-unwritable"      # cannot record it, so do not block
    return f"BLOCK {len(edited)}"


try:
    verdict = main()
    sid = (json.loads(os.environ.get("RG_PAYLOAD") or "{}").get("session_id") or "?")
    log(f"{verdict} session={sid}")
    print(verdict.split(" ")[0] if verdict.startswith("PASS") else verdict)
except Exception as exc:
    log(f"PASS internal-error={type(exc).__name__}")
    print("PASS")
RGPY
)
  case "$RG_VERDICT" in
    BLOCK*)
      RG_N=${RG_VERDICT#BLOCK }
      echo "REVIEW GATE: $RG_N source files changed this session and nothing has reviewed them. Writing and reviewing are separate passes, so run /code-review or spawn the code-reviewer agent, then stop again. Fires once per session; the next stop passes regardless." >&2
      exit 2
      ;;
  esac
fi

# Low-noise /done nudge (non-blocking): uncommitted changes and no fresh
# done-receipt (written by pre-commit-verify.sh on a passing bundle) → one line.
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$GIT_ROOT" ] && [ -n "$(git -C "$GIT_ROOT" status --porcelain 2>/dev/null | head -1)" ]; then
  if [ -z "$(find "$GIT_ROOT/.omc/state/done-receipt" -mmin -30 2>/dev/null)" ]; then
    printf '%s\n' '{"systemMessage":"[verify-gate] uncommitted changes + no done-receipt in the last 30 min — consider running /done before wrapping up."}'
  fi
fi

REPO_ROOT=$(find_flag_root) || exit 0
LOG="$REPO_ROOT/.claude/state/verify-gate.log"
BASELINE="$REPO_ROOT/.claude/state/verify-baseline"
FLAG="$REPO_ROOT/.claude/state/needs-verify"
mkdir -p "$(dirname "$LOG")"

# If baseline file is absent, the auto-arm background capture hasn't finished
# (or never ran). Without a trusted baseline we cannot tell a regression from a
# pre-existing error — so clear the flag and pass rather than block falsely.
if [ ! -f "$BASELINE" ]; then
  echo "[verify-gate] $(date '+%F %T') no baseline (auto-arm not finished) — pass" >> "$LOG"
  rm -f "$FLAG"
  exit 0
fi

BASE=$(grep -oE 'tsc_errors=[0-9]+' "$BASELINE" | cut -d= -f2)
BASE=${BASE:-0}

CUR=$(count_tsc_errors "$REPO_ROOT")

{
  echo "[verify-gate] $(date '+%F %T')"
  echo "  baseline_tsc_errors=$BASE"
  echo "  current_tsc_errors=$CUR"
} >> "$LOG"

if [ "$CUR" -gt "$BASE" ]; then
  cd "$REPO_ROOT"
  if grep -q '"build"' package.json 2>/dev/null && grep -q 'tsc -b\|tsc --build' package.json 2>/dev/null; then
    npx --no-install tsc -b 2>&1 | tail -30 >> "$LOG"
  else
    npx --no-install tsc --noEmit 2>&1 | tail -30 >> "$LOG"
  fi
  echo "VERIFICATION FAILED: tsc errors regressed ($BASE → $CUR). See $LOG. Flag still set." >&2
  exit 2
fi

# Pass: tests if configured and not placeholder
if [ -f "$REPO_ROOT/package.json" ] && grep -q '"test"' "$REPO_ROOT/package.json" \
   && ! grep -q '"test": *"echo' "$REPO_ROOT/package.json"; then
  cd "$REPO_ROOT"
  # Run tests ONE-SHOT. Bare `npm test` is `vitest`/`jest` in watch mode in many
  # repos — it never exits cleanly and crashes if files change mid-watch (e.g. a
  # concurrent session deleting a test file), tripping this gate spuriously.
  # Prefer an explicit one-shot script; else force vitest run mode.
  if grep -q '"test:run"' package.json 2>/dev/null; then
    TEST_CMD="npm run test:run --silent"
  elif grep -q '"test:ci"' package.json 2>/dev/null; then
    TEST_CMD="npm run test:ci --silent"
  elif grep -qE '"test": *"[^"]*vitest' package.json 2>/dev/null; then
    TEST_CMD="npm test --silent -- --run"
  else
    TEST_CMD="npm test --silent"
  fi
  if ! $TEST_CMD >> "$LOG" 2>&1; then
    echo "VERIFICATION FAILED: tests failed. See $LOG. Flag still set." >&2
    exit 2
  fi
fi

rm -f "$FLAG" "$BASELINE"
echo "[verify-gate] PASS — flag + baseline cleared" >> "$LOG"
exit 0
