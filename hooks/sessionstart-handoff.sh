#!/usr/bin/env bash
# SessionStart hook — re-inject the last handoff so a FRESH session resumes clean.
#
# Why: this is the other half of the "don't resume the bloated session" model.
# You open a brand-new `claude` in the worktree; this hook prints the compact
# handoff to stdout, which Claude Code adds to the new session's context. You get
# oriented in ~40 lines instead of reloading a 6 MB transcript.
#
# Reads the central store written by stop-handoff.sh / precompact-handoff.sh, plus
# a curated SESSION_NOTES.md (from the /handoff skill) if one exists in the repo.
# Skips on `resume` (that path already restores the conversation). Always exits 0.
set -uo pipefail

input=$(cat 2>/dev/null || true)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -z "$cwd" ] && cwd="$PWD"
source_kind=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null || true)

# On a real --resume the full conversation is already restored; don't double up.
[ "$source_kind" = "resume" ] && exit 0

HANDOFF_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/handoffs"
slug=$(printf '%s' "$cwd" | sed 's#^/##; s#[/ ]#-#g')
live="$HANDOFF_DIR/${slug}.md"
compact="$HANDOFF_DIR/${slug}.compact.md"
notes="$cwd/SESSION_NOTES.md"

emitted=0
# Only surface handoffs that are still fresh (<14 days) to avoid stale noise.
if [ -f "$live" ] && [ -z "$(find "$live" -mtime +14 2>/dev/null)" ]; then
  echo "=== Last session handoff (auto) ==="
  cat "$live" 2>/dev/null || true
  emitted=1
fi
if [ -f "$compact" ] && [ -z "$(find "$compact" -mtime +14 2>/dev/null)" ]; then
  echo
  echo "=== Preserved pre-compaction notes (most recent) ==="
  tail -n 40 "$compact" 2>/dev/null || true
  emitted=1
fi
if [ -f "$notes" ]; then
  echo
  echo "=== SESSION_NOTES.md (curated /handoff) ==="
  head -n 60 "$notes" 2>/dev/null || true
  emitted=1
fi

[ "$emitted" -eq 1 ] && { echo; echo "_Resume from the above. Verify branch/dirty state before acting; don't trust it blindly._"; }
exit 0
