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
  if ! npm test --silent >> "$LOG" 2>&1; then
    echo "VERIFICATION FAILED: tests failed. See $LOG. Flag still set." >&2
    exit 2
  fi
fi

rm -f "$FLAG" "$BASELINE"
echo "[verify-gate] PASS — flag + baseline cleared" >> "$LOG"
exit 0
