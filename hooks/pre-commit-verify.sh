#!/bin/bash
# Pre-commit verification hook
# Blocks `git commit` when the repo's verification bundle fails.
#   - package.json declares a `ci:local` script → run that (600s cap), same
#     bundle the /done skill runs
#   - else: tsc type check (as before), plus lint when a lint config exists
# On success writes .omc/state/done-receipt (date + HEAD) so the Stop-hook
# /done nudge in verify-gate.sh stays quiet for 30 min.
# Directly addresses the "false done" problem: Claude claiming verification
# complete before the checks actually pass.
#
# Bypass for WIP: include [wip], [skip-verify], or "WIP" in commit message.
# Escape hatch: DONE_GATE_SKIP=1 skips the whole bundle.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only act on `git commit` commands
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Allow bypass for WIP / intentional partial commits
case "$COMMAND" in
  *"[skip-verify]"*|*"[wip]"*|*"WIP"*|*"--amend"*) exit 0 ;;
esac

# Escape hatch: skip the verification bundle entirely
if [ "${DONE_GATE_SKIP:-0}" = "1" ]; then
  echo "pre-commit-verify: bundle skipped (DONE_GATE_SKIP=1)" >&2
  exit 0
fi

# Surface current branch (catch wrong-branch commits)
BRANCH=$(git branch --show-current 2>/dev/null)
echo "Committing to branch: $BRANCH" >&2

# Cap the ci:local bundle at 600s. coreutils timeout when present; else a
# bash-native watchdog — this machine ships neither timeout nor gtimeout, and
# an uncapped bundle would stall `git commit` until the outer hook timeout
# kills the whole hook non-cleanly (review finding 2026-07-19).
run_capped() {
  if command -v timeout >/dev/null 2>&1; then timeout -k 5 600 "$@"; return
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 600 "$@"; return
  fi
  "$@" &
  local cmd_pid=$!
  ( sleep 600; kill -TERM "$cmd_pid" 2>/dev/null; sleep 5; kill -KILL "$cmd_pid" 2>/dev/null ) &
  local dog_pid=$!
  wait "$cmd_pid"
  local rc=$?
  kill "$dog_pid" 2>/dev/null
  wait "$dog_pid" 2>/dev/null
  return $rc
}

# Receipt = proof a verification bundle passed recently (read by verify-gate.sh)
write_receipt() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"
  mkdir -p "$root/.omc/state"
  {
    date '+%Y-%m-%dT%H:%M:%S%z'
    git rev-parse HEAD 2>/dev/null || echo "no-HEAD"
  } > "$root/.omc/state/done-receipt"
}

# --- verification bundle ---
if [ -f package.json ] && jq -e '.scripts["ci:local"] // empty' package.json >/dev/null 2>&1; then
  OUTPUT=$(run_capped npm run ci:local --silent 2>&1)
  EXIT_CODE=$?
  BUNDLE="ci:local"
else
  # Skip if not a TypeScript project
  if [ ! -f tsconfig.json ]; then
    exit 0
  fi
  # Run tsc -b (CI parity) when project refs exist; else --noEmit
  if grep -q '"references"' tsconfig.json 2>/dev/null; then
    OUTPUT=$(npx tsc -b 2>&1)
  else
    OUTPUT=$(npx tsc --noEmit 2>&1)
  fi
  EXIT_CODE=$?
  BUNDLE="tsc"
  # Add lint only when a lint config exists
  if [ $EXIT_CODE -eq 0 ]; then
    if [ -f package.json ] && jq -e '.scripts.lint // empty' package.json >/dev/null 2>&1; then
      OUTPUT=$(npm run lint --silent 2>&1)
      EXIT_CODE=$?
      BUNDLE="tsc+lint"
    elif ls .eslintrc* eslint.config.* >/dev/null 2>&1; then
      OUTPUT=$(npx --no-install eslint . 2>&1)
      EXIT_CODE=$?
      BUNDLE="tsc+eslint"
    fi
  fi
fi

if [ $EXIT_CODE -ne 0 ]; then
  case $EXIT_CODE in
    124|137|143) echo "BLOCKED: verification bundle ($BUNDLE) timed out after 600s." >&2 ;;
  esac
  echo "BLOCKED: verification bundle ($BUNDLE) failed. Fix errors before committing." >&2
  echo "Bypass with [wip] or [skip-verify] in commit message, or DONE_GATE_SKIP=1, if intentional." >&2
  echo "" >&2
  echo "$OUTPUT" | tail -30 >&2
  exit 2
fi

write_receipt
exit 0
