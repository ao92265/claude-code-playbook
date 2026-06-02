#!/usr/bin/env bash
# PreCompact hook — preserve state BEFORE compaction discards it.
#
# Why: auto-compaction fires at ~95% context, mid-thought, and is lossy. What
# reliably dies: start-of-session rules, architecture rationale, the full list of
# files you touched, and the chain of what you asked. This hook snapshots that
# the instant before it's lost. Deterministic (no LLM call — safe, fast, free,
# and no risk of recursing into another `claude` process from inside a hook).
#
# Appends (never overwrites) so several compactions in one long day accumulate.
# Output: $CLAUDE_CONFIG_DIR/handoffs/<repo-slug>.compact.md
#
# Optional LLM enrichment: set HANDOFF_LLM=1 to also fire a non-blocking
# `claude --bare -p` summary in the background (off by default).
set -uo pipefail

input=$(cat 2>/dev/null || true)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -z "$cwd" ] && cwd="$PWD"
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null || true)
trigger=$(printf '%s' "$input" | jq -r '.trigger // "auto"' 2>/dev/null || true)

HANDOFF_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/handoffs"
mkdir -p "$HANDOFF_DIR" 2>/dev/null || true
slug=$(printf '%s' "$cwd" | sed 's#^/##; s#[/ ]#-#g')
out="$HANDOFF_DIR/${slug}.compact.md"
ts=$(date '+%Y-%m-%d %H:%M')

allprompts=""
files=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  allprompts=$(jq -r 'select(.type=="user") | .message.content
                      | if type=="array" then (map(select(.type=="text").text)|join(" "))
                        elif type=="string" then . else empty end
                      | gsub("[\n\r\t]+";" ")' "$transcript" 2>/dev/null \
    | grep -vE '^[[:space:]]*$' \
    | grep -vE '<(system-reminder|command-name|command-message|command-args|local-command|task-notification|usage|result)|^Caveat:|truncated [0-9]+ chars|Your tool call was malformed|tool call was malformed' \
    | cut -c1-200 | tail -12 || true)
  files=$(jq -r 'select(.type=="assistant") | .message.content[]?
                 | select(.type=="tool_use" and (.name=="Edit" or .name=="Write" or .name=="MultiEdit" or .name=="NotebookEdit"))
                 | .input.file_path // empty' "$transcript" 2>/dev/null \
    | sort -u | head -30 || true)
fi

{
  echo "## Pre-compaction snapshot — $ts (trigger: $trigger)"
  if [ -n "$files" ]; then
    echo "**Files edited this session:**"
    while IFS= read -r f; do [ -n "$f" ] && echo "- \`$f\`"; done <<< "$files"
  fi
  if [ -n "$allprompts" ]; then
    echo
    echo "**Ask history this session (oldest→newest):**"
    while IFS= read -r line; do [ -n "$line" ] && echo "- $line"; done <<< "$allprompts"
  fi
  echo
  echo "---"
} >> "$out" 2>/dev/null || true

# Optional, opt-in, non-blocking LLM enrichment.
if [ "${HANDOFF_LLM:-0}" = "1" ] && command -v claude >/dev/null 2>&1 && [ -n "$transcript" ]; then
  (
    summary=$(tail -n 600 "$transcript" 2>/dev/null \
      | jq -r 'select(.type=="user" or .type=="assistant") | .message.content
               | if type=="array" then (map(select(.type=="text").text)|join(" ")) elif type=="string" then . else empty end' 2>/dev/null \
      | tail -120 \
      | claude --bare -p 'Summarize this session into <=12 lines: Decisions made (+why), Constraints to remember, and the single Next concrete step. Markdown bullets only.' 2>/dev/null || true)
    if [ -n "$summary" ]; then
      { echo "### LLM summary — $ts"; echo "$summary"; echo; echo "---"; } >> "$out" 2>/dev/null || true
    fi
  ) >/dev/null 2>&1 &
fi

exit 0
