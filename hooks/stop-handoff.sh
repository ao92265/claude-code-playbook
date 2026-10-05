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
# shellcheck source=lib/handoff-key.sh
. "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/lib/handoff-key.sh"
# Name via stdin > env > the native registry (~/.claude/sessions/<pid>.json). Stdin never
# actually carries one (hooks reference, v2.1.223), so the registry lookup is what makes a
# `claude -n` / /rename session write under its OWN key instead of the shared cwd slot.
# shellcheck source=lib/session-ident.sh
. "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/lib/session-ident.sh"
sname=$(session_ident_resolve "$input")
slug=$(handoff_key "$cwd" "$sname")
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

# Open questions pinned by open-question.py for THIS session. Steal from
# ai-memory's Handoff struct: it carries open_questions as a first-class field,
# because "what was still unanswered" is the one thing a fresh session cannot
# re-derive from git or the transcript tail. Keyed by session id, same key the
# per-session handoff copy uses below.
openq=""
if [ -n "$transcript" ]; then
  _sid=$(basename "$transcript" .jsonl 2>/dev/null || true)
  _qfile="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/open-question/${_sid}.json"
  if [ -n "$_sid" ] && [ -f "$_qfile" ]; then
    openq=$(jq -r '.questions // [] | .[]' "$_qfile" 2>/dev/null \
      | grep -vE '^[[:space:]]*$' | head -3 | cut -c1-200 || true)
  fi
fi

# Verification evidence. evidence-recorder.sh has been logging real runs to
# <repo>/.claude/evidence/runs.jsonl all along and nothing read it back, so a
# resumed session still had to re-run everything to find out what was green.
# Derived by reading records, never by recalling a claim: a run that produced no
# record does not appear here, which is the point.
evidence=""
_ledger="$cwd/.claude/evidence/runs.jsonl"
[ -f "$_ledger" ] || _ledger=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)/.claude/evidence/runs.jsonl
if [ -f "$_ledger" ]; then
  evidence=$(tail -n 60 "$_ledger" 2>/dev/null | jq -r '
    . as $r
    | (($r.tail // "")
       # "0 failed" and "0 errors" are what a PASSING run prints. Strip the
       # zero-counts before looking for failure words, or every green test suite
       # that reports its failure count reads as red.
       | gsub("(?i)\\b(0|no)\\s+(failed|failures|errors?|problems?)";"")
       | gsub("(?i)\\bfailures?:\\s*0";"")) as $t
    | (if   ($t | test("(?i)(\\bfail(ed|ing|ures?)?\\b|\\berrors?\\b|✗|✖)")) then "RED  "
       elif ($t | test("(?i)(passed|succeeded|successful|compiled|up to date|✓|✔|all tests)")) then "green"
       else "?    " end) as $verdict
    | "\($verdict) \($r.cmd|tostring|.[0:90])  (\($r.at|tostring|.[0:16]|sub("T";" ")))"
  ' 2>/dev/null | tail -6 || true)
fi

# The one field that genuinely cannot be derived: what the NEXT session should aim
# at. leg-scope.sh already made this session state its own finish line, so reuse
# it rather than asking twice. Absent means the handoff says so out loud instead
# of quietly shipping without one.
intent=""
if [ -n "$transcript" ]; then
  _isid=$(basename "$transcript" .jsonl 2>/dev/null || true)
  _ifile="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/leg-scope/stated-${_isid}"
  [ -f "$_ifile" ] && intent=$(sed -n 's/^line=//p' "$_ifile" 2>/dev/null | head -1 || true)
fi

ts=$(date '+%Y-%m-%d %H:%M')
{
  echo "# Handoff — $(basename "$cwd") — $ts"
  echo "_Auto (stop-handoff). Live state, overwritten each turn. Start a FRESH session here and read this — don't \`--resume\` the bloated one._"
  echo
  if [ -n "$intent" ]; then
    echo "## Next intent (from this session's stated finish line)"
    echo "- $intent"
    echo
  else
    echo "## Next intent"
    echo "- NOT STATED. Set one before editing: \`echo \"leg-done: <one line>\"\`"
    echo
  fi
  echo "## State"
  echo "- Path: \`$cwd\`"
  # Friendly session name. Comes from the hook's stdin, or from the env when
  # checkpoint-sessions drives this hook. restore-sessions reads it to label the
  # reopened tab `-n <name>` instead of a cwd+sid slug — and sessionstart reads it
  # to prove a handoff under an ambiguous historical key really belongs to the
  # session picking it up, rather than to a sibling that shared that key.
  [ -n "$sname" ] && echo "- Session: $sname"
  [ -n "$branch" ] && echo "- Branch: \`$branch\`"
  [ -n "$lastcommit" ] && echo "- Last commit: $lastcommit"
  echo "- Uncommitted: ${dirtycount:-0} file(s)"
  if [ -n "$dirty" ]; then
    echo '```'
    echo "$dirty"
    echo '```'
  fi
  if [ -n "$evidence" ]; then
    echo
    echo "## Verified this session (from the evidence ledger, not from memory)"
    echo '```'
    echo "$evidence"
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
  if [ -n "$openq" ]; then
    echo
    echo "## Open questions (unanswered at stop)"
    while IFS= read -r line; do [ -n "$line" ] && echo "- $line"; done <<< "$openq"
  fi
} > "$out" 2>/dev/null || true

# Per-session copy: the cwd-keyed file above is newest-wins, so N sessions run
# from the same dir (esp. $HOME) collapse into one. Keep a per-session copy under
# sessions/ (isolated subdir — morning.sh and sessionstart's globs never see it),
# keyed by the session id from the transcript path. restore-sessions.sh reads
# these to reopen EACH parked session individually, launching it with
# RESTORE_HANDOFF pointing back at its own copy.
if [ -n "$transcript" ]; then
  sid=$(basename "$transcript" .jsonl 2>/dev/null || true)
  if [ -n "$sid" ]; then
    mkdir -p "$HANDOFF_DIR/sessions" 2>/dev/null || true
    cp "$out" "$HANDOFF_DIR/sessions/${slug}__${sid}.md" 2>/dev/null || true
    # Keep the subdir bounded — drop per-session copies older than 14 days
    # (matches sessionstart-handoff's freshness window).
    find "$HANDOFF_DIR/sessions" -name '*.md' -mtime +14 -delete 2>/dev/null || true
  fi
fi

exit 0
