#!/usr/bin/env bash
# evidence-recorder.sh — PostToolUse(Bash): record verification runs as they happen.
#
# The passive half of the evidence ledger. It never blocks, never asks and never
# changes a command; it watches Bash results go past and writes the ones that
# look like verification to <repo>/.claude/evidence/runs.jsonl.
#
# The point is that no habit has to change. The agent keeps typing `dotnet test`,
# and by the time it writes a PR body the numbers it wants to quote already have
# records behind them. Nothing here can be satisfied by typing, which is the
# whole reason the ledger exists: see the five Scheduler PRs of 19 Aug 2026,
# where every merge blocker was a figure no run had produced.
#
# Deliberately silent on failure. This is a recorder, not a gate; the gates that
# read the file already treat a missing record as "unsupported" and ask. A
# recorder that shouted would fire on every command in the session.
set -uo pipefail

IFS= read -r -d '' INPUT <&0 || true
command -v jq >/dev/null 2>&1 || exit 0
printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || exit 0

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$COMMAND" ] || exit 0

# What counts as verification. Kept to commands whose output carries the figures
# people quote: test counts, build sizes, exit codes. A command that only reads
# (git log, cat, ls) has nothing to support a claim with.
case "$COMMAND" in
  *"dotnet test"*|*"dotnet build"*|*"dotnet run"*) ;;
  *"npm test"*|*"npm run test"*|*"npm run build"*|*"ng test"*|*"ng build"*) ;;
  *"npx vitest"*|*vitest*|*jest*|*pytest*|*"go test"*|*"cargo test"*) ;;
  *"tsc "*|*"tsc -b"*|*"npx tsc"*) ;;
  *"hooks-smoke-test"*|*"ci:local"*) ;;
  *) exit 0 ;;
esac

# The recorder must not itself become a source of claims about the wrong repo.
# Resolve the root the command actually ran in, preferring an explicit cd in the
# command text over the session cwd, for the same worktree reason the gates do.
CD_TARGET=$(printf '%s' "$COMMAND" \
  | grep -oE "\b(cd|pushd)[[:space:]]+(\"[^\"]+\"|'[^']+'|[^&;|]+)" | head -1 \
  | sed -E 's/^[[:space:]]*(cd|pushd)[[:space:]]+//; s/[[:space:]]+$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')
case "$CD_TARGET" in
  \~)   CD_TARGET="$HOME" ;;
  \~/*) CD_TARGET="$HOME/${CD_TARGET#\~/}" ;;
esac
BASE="${CD_TARGET:-$CWD}"
[ -d "$BASE" ] || BASE="$CWD"
ROOT=$(git -C "$BASE" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$BASE")
[ -n "$ROOT" ] && [ -d "$ROOT" ] || exit 0

HEAD_SHA=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf '')
DIR="$ROOT/.claude/evidence"
mkdir -p "$DIR" 2>/dev/null || exit 0

# tool_response shape varies by harness version: a bare string on some, an object
# carrying stdout/stderr on others. Take whichever is present rather than
# assuming, because guessing wrong records an empty tail and an empty tail is
# indistinguishable from a run that printed nothing.
OUT=$(printf '%s' "$INPUT" | jq -r '
  (.tool_response // empty) as $r
  | if ($r | type) == "string" then $r
    elif ($r | type) == "object" then
      ([$r.stdout // "", $r.stderr // "", $r.output // "", ($r.content // "" | tostring)] | map(select(. != "")) | join("\n"))
    else "" end')
[ -n "$OUT" ] || exit 0

# -c matters: this file is read line by line elsewhere, and jq -Rs without it
# pretty-prints one record across eight lines.
printf '%s' "$OUT" | tail -n 40 | jq -cRs --arg cmd "$COMMAND" --arg cwd "$ROOT" \
  --arg head "$HEAD_SHA" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{cmd:$cmd,cwd:$cwd,head:$head,exit:null,at:$at,tail:.}' \
  >> "$DIR/runs.jsonl" 2>/dev/null || true

exit 0
