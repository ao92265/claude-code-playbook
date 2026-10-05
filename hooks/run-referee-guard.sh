#!/usr/bin/env bash
# run-referee-guard.sh
#
# PreToolUse hook (matcher: * — every tool). Enforcement half of Run Referee.
# The referee daemon (scripts/run-referee.py, launchd every 10 min) writes a
# sentinel file named after a session's uuid when it verdicts pause/kill:
#   ~/.claude/run-referee/sentinels/<session-uuid>
# This hook checks whether ITS OWN session has a sentinel and, if so, blocks
# the tool call with the verdict + resume instructions. The blocked run then
# halts; stop-handoff.sh writes the normal handoff on Stop.
#
# No sentinel → exit 0 fast (one stat call). Never blocks other sessions.
# Exit codes: 0 allow · 2 block (CC hook-denial convention)
set -uo pipefail

SDIR="$HOME/.claude/run-referee/sentinels"
[ -d "$SDIR" ] || exit 0

INPUT=$(cat 2>/dev/null || true)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
[ -z "$TRANSCRIPT" ] && exit 0
UUID=$(basename "$TRANSCRIPT" .jsonl)
SENTINEL="$SDIR/$UUID"
[ -f "$SENTINEL" ] || exit 0

# Full-path check: a bare uuid reused across project dirs must not block the
# wrong session. Empty recorded path (legacy sentinel) falls back to uuid match.
SPATH=$(jq -r '.transcript_path // empty' "$SENTINEL" 2>/dev/null || true)
if [ -n "$SPATH" ] && [ "$SPATH" != "$TRANSCRIPT" ]; then
  exit 0
fi

# Escape hatch: the ONE action a stopped session may still take is writing its
# own rich reboot handoff. Before this exception, a refereed session could not
# run /reboot at all (the block covers every tool, including the Write the
# skill needs), so a 4h stop left only the thin 600-byte auto note and the
# next session started half-blind. Write/Edit into the reboots dir only,
# nothing else; no ".." so the hole cannot be steered elsewhere.
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ]; then
  FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
  REBOOT_DIR="${OMC_REBOOT_DIR:-$HOME/.claude/reboots}"
  case "$FP" in
    *..*) : ;;
    "$REBOOT_DIR"/*.md) exit 0 ;;
  esac
fi

# Second hole: /keep. Pinning a terminal is how the user stops the rotator clearing
# it, and a paused session is exactly the one he wants pinned. Only the skill
# itself and one bare keep.sh call; anything chained onto it stays blocked.
if [ "$TOOL" = "Skill" ]; then
  [ "$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)" = "keep" ] && exit 0
fi
if [ "$TOOL" = "Bash" ]; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
  case "$CMD" in *$'\n'*) CMD="" ;; esac
  printf '%s' "$CMD" | grep -qE '^(rtk )?(~|/Users/[^/ ]+|\$HOME)/\.claude/scripts/keep\.sh( (on|off|status))?$' && exit 0
fi

VERDICT=$(jq -r '.verdict // "pause"' "$SENTINEL" 2>/dev/null || echo pause)
REASON=$(jq -r '.reason // "unspecified"' "$SENTINEL" 2>/dev/null || echo unspecified)

cat >&2 <<MSG
[run-referee] $VERDICT: this run has been stopped by the Run Referee watchdog.

Reason: $REASON

Do NOT retry this tool call or route around this block. One action remains
allowed: Write a reboot handoff to ~/.claude/reboots/reboot-<YYYY-MM-DD-HHMM>-<slug>.md
(self-contained reprompt for a fresh session; the reboot-stamp hook adds the
identity block for you, and Bash stays blocked so do not try to run scripts).
Write that file now, summarize where you are inside it, then end the turn.
The user resumes with /clear or a fresh session in this folder.

(Human override: rm ~/.claude/run-referee/sentinels/$UUID)
MSG
exit 2
