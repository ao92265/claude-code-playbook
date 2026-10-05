#!/usr/bin/env bash
# pr-gate-ack-promote.sh — PostToolUse(Bash): turn "this was asked" into
# "a human said yes".
#
# The four pre-PR gates cannot see the answer to their own prompt. A PreToolUse
# hook returns a verdict and is gone; nothing tells it whether the human pressed
# Yes or No. So a gate that remembers its own ask remembers a refusal as consent:
# decline the prompt, re-run the identical command, and it goes straight through.
#
# PostToolUse is the missing half, because it fires only when the command
# actually ran. A refusal never reaches here. So:
#
#   ask   -> the gate writes <ack>.pending, holding the command's digest
#   yes   -> the command runs, this promotes <ack>.pending to <ack>
#   no    -> nothing runs, the pending marker stays pending, the gate asks again
#
# Matching is on the command text alone, which is all this hook can see. That is
# enough: the pending marker was written by a gate examining that same command,
# and a command that differs is a different question anyway.
#
# Registered at session start like every hook, so a session already running when
# this landed has no promoter and keeps the older behaviour until it restarts.
set -uo pipefail

. "${BASH_SOURCE[0]%/*}/lib/pr-gate-common.sh"

pg_read_input
command -v jq >/dev/null 2>&1 || exit 0

TOOL=$(printf '%s' "$PG_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$TOOL" = "Bash" ] || exit 0
PG_COMMAND=$(printf '%s' "$PG_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$PG_COMMAND" ] || exit 0

DIR="${PR_GATE_ACK_DIR:-$HOME/.claude/state/pr-gate-acks}"
[ -d "$DIR" ] || exit 0

WANT=$(pg_digest "$PG_COMMAND")
[ -n "$WANT" ] || exit 0

for pending in "$DIR"/*.pending; do
  [ -e "$pending" ] || continue
  # A pending marker nobody ever answered is just litter after a week, and the
  # question it stood for has long since moved to another commit.
  if [ -n "$(find "$pending" -mtime +7 2>/dev/null)" ]; then
    rm "$pending" 2>/dev/null || true
    continue
  fi
  got=$(cat "$pending" 2>/dev/null || true)
  [ "$got" = "$WANT" ] || continue
  approved="${pending%.pending}"
  : > "$approved" 2>/dev/null || true
  rm "$pending" 2>/dev/null || true
done

exit 0
