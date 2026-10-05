#!/usr/bin/env bash
# checkpoint-sessions.sh — snapshot EVERY live Claude Code session into its own
# per-session handoff right now, so a reboot loses nothing.
#
# The Stop hook only writes a handoff when a session finishes a turn, and it keys
# the cwd file newest-wins — so several sessions launched from the same dir (esp.
# $HOME) collapse, and an idle session that hasn't turned recently may have no
# fresh handoff at all. This walks every LIVE session (from ~/.claude/sessions/
# <pid>.json), finds its transcript, and replays it through stop-handoff.sh — the
# same proven extractor — to write a per-session handoff. No need to touch the
# terminals or make each session take a turn.
#
# Run this BEFORE a reboot, then reopen with:  restore-sessions --all
#
# Usage:
#   checkpoint-sessions.sh          # checkpoint all live sessions
#   checkpoint-sessions.sh --list   # show what would be checkpointed, write nothing
set -uo pipefail

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SESS_DIR="$CFG/sessions"
HOOK="$CFG/hooks/stop-handoff.sh"
PROJ="$CFG/projects"
LIST=0
[ "${1:-}" = "--list" ] && LIST=1

[ -d "$SESS_DIR" ] || { echo "No sessions dir at $SESS_DIR" >&2; exit 1; }
[ -f "$HOOK" ] || { echo "stop-handoff hook missing at $HOOK" >&2; exit 1; }

n=0 skipped=0
for j in "$SESS_DIR"/*.json; do
  [ -f "$j" ] || continue
  pid=$(jq -r '.pid // empty' "$j" 2>/dev/null)
  sid=$(jq -r '.sessionId // empty' "$j" 2>/dev/null)
  cwd=$(jq -r '.cwd // empty' "$j" 2>/dev/null)
  name=$(jq -r '.name // empty' "$j" 2>/dev/null)
  # Skip dead PIDs (session closed but json not yet reaped).
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then skipped=$((skipped+1)); continue; fi
  [ -n "$sid" ] && [ -n "$cwd" ] || { skipped=$((skipped+1)); continue; }
  tr=$(find "$PROJ" -name "${sid}.jsonl" 2>/dev/null | head -1)
  [ -n "$tr" ] && [ -f "$tr" ] || { echo "  (no transcript for ${name:-$sid} — skipped)"; skipped=$((skipped+1)); continue; }
  if [ "$LIST" -eq 1 ]; then
    echo "  would checkpoint: ${name:-$sid}  ($cwd)"
  else
    printf '{"cwd":"%s","transcript_path":"%s"}' "$cwd" "$tr" \
      | HANDOFF_SESSION_NAME="$name" bash "$HOOK" 2>/dev/null || true
    echo "  checkpointed: ${name:-$sid}  ($cwd)"
  fi
  n=$((n+1))
done

echo
if [ "$LIST" -eq 1 ]; then
  echo "$n live session(s) would be checkpointed ($skipped skipped). Run without --list to write them."
else
  echo "Checkpointed $n live session(s) ($skipped skipped)."
  echo "Now reopen after reboot with:  restore-sessions --all"
fi
