#!/usr/bin/env bash
# Stop hook — write a compact, deterministic "where I left off" handoff.
#
# Why: long Claude Code sessions get huge. `claude --resume` reloads the FULL
# transcript, so a resumed session is already near-limit and degraded. The fix
# is to NOT resume — start a fresh session and read this small handoff instead.
#
# Fires after every assistant turn. Zero LLM cost, pure git + transcript parse.
# Always exits 0 so it can never block the session.
#
# Output: $CLAUDE_CONFIG_DIR/handoffs/<repo-slug>.md  (central store — NOT written
# into your repo, so it never pollutes git status or gets committed by accident).
#
# Companions:
#   sessionstart-handoff.sh  — re-injects this file when a fresh session opens
#   precompact-handoff.sh    — preserves richer state just before compaction
#   /handoff skill           — curated, human-authored SESSION_NOTES.md (on demand)
#   tools/morning.sh         — one briefing across ALL parked sessions
set -uo pipefail

input=$(cat 2>/dev/null || true)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null || true)
[ -z "$cwd" ] && cwd="$PWD"

HANDOFF_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/handoffs"
mkdir -p "$HANDOFF_DIR" 2>/dev/null || true
slug=$(printf '%s' "$cwd" | sed 's#^/##; s#[/ ]#-#g')
out="$HANDOFF_DIR/${slug}.md"

branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
lastcommit=$(git -C "$cwd" log -1 --oneline 2>/dev/null || true)
dirty=$(git -C "$cwd" status --short 2>/dev/null | head -15 || true)
dirtycount=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || true)

prompts=""
lastaction=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  # Real user prompts only: text blocks, excluding tool results and injected
  # <system-reminder>/<command-name> noise. Last 3, truncated.
  # gsub collapses each message to ONE line so a multi-line injected block (e.g.
  # a <task-notification> with an inner <usage> line) is filtered whole, not
  # line-by-line (which would leak its inner lines).
  prompts=$(tail -n 400 "$transcript" 2>/dev/null \
    | jq -r 'select(.type=="user") | .message.content
             | if type=="array" then (map(select(.type=="text").text)|join(" "))
               elif type=="string" then . else empty end
             | gsub("[\n\r\t]+";" ")' 2>/dev/null \
    | grep -vE '^[[:space:]]*$' \
    | grep -vE '<(system-reminder|command-name|command-message|command-args|local-command|task-notification|usage|result)|^Caveat:|truncated [0-9]+ chars|Your tool call was malformed|tool call was malformed' \
    | tail -3 | cut -c1-200 || true)
  # Last assistant action: text or the last tool call it made.
  lastaction=$(tail -n 200 "$transcript" 2>/dev/null \
    | jq -r 'select(.type=="assistant") | .message.content
             | if type=="array" then
                 (map(if .type=="text" then .text
                      elif .type=="tool_use" then ("→ "+.name+" "+((.input.description // .input.command // .input.file_path // "")|tostring))
                      else empty end)|join(" | "))
               else empty end' 2>/dev/null \
    | grep -vE '^[[:space:]]*$' | tail -1 | cut -c1-240 || true)
fi

ts=$(date '+%Y-%m-%d %H:%M')
{
  echo "# Handoff — $(basename "$cwd") — $ts"
  echo "_Auto (stop-handoff). Live state, overwritten each turn. Start a FRESH session here and read this — don't \`--resume\` the bloated one._"
  echo
  echo "## State"
  echo "- Path: \`$cwd\`"
  [ -n "$branch" ] && echo "- Branch: \`$branch\`"
  [ -n "$lastcommit" ] && echo "- Last commit: $lastcommit"
  echo "- Uncommitted: ${dirtycount:-0} file(s)"
  if [ -n "$dirty" ]; then
    echo '```'
    echo "$dirty"
    echo '```'
  fi
  if [ -n "$prompts" ]; then
    echo
    echo "## Recent asks (oldest→newest)"
    while IFS= read -r line; do [ -n "$line" ] && echo "- $line"; done <<< "$prompts"
  fi
  if [ -n "$lastaction" ]; then
    echo
    echo "## Last action"
    echo "- $lastaction"
  fi
} > "$out" 2>/dev/null || true

exit 0
