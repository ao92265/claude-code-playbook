#!/usr/bin/env bash
# restate-gate.sh - one hook, three modes. Makes a fresh session say back what it
# was asked before its first source edit.
#
#   --arm     UserPromptSubmit. Arms on the session's first real ask.
#   --record  PostToolUse(Bash). Stamps the restatement.
#   --gate    PreToolUse(Edit|Write|MultiEdit). Blocks the first source edit
#             until a restatement exists. Blocks once, then stands down.
#
# Why: misread requests are the top friction in the insights report (9 sessions).
# A one-line restatement before the first edit puts the misread on screen while
# it is still cheap to correct, instead of after the work is built.
#
# Continuation sessions are skipped: leg-scope already asks them for a finish line.
# Every outcome goes to state/restate-gate/log so the gate can be measured.
#
# Exit codes: 0 allow, 2 block (gate mode only)
# Disable: CLAUDE_SKIP_HOOKS=restate-gate
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,restate-gate,*) exit 0 ;; esac
case "${CLAUDE_CODE_ENTRYPOINT:-cli}" in cli|claude-vscode|claude-desktop|claude-desktop-3p) ;; *) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
MODE="${1:---gate}"
INPUT=$(cat 2>/dev/null || true)
printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || exit 0

SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-')
[ -n "$SID" ] || exit 0
DIR="${RESTATE_GATE_STATE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/restate-gate}"
mkdir -p "$DIR" 2>/dev/null || exit 0
SEEN="$DIR/seen-${SID}"; ARMED="$DIR/armed-${SID}"; STATED="$DIR/stated-${SID}"; PASSED="$DIR/passed-${SID}"
log() { printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SID" "$1" >> "$DIR/log" 2>/dev/null || true; }

case "$MODE" in
--arm)
  # The first real ask decides. Once one has armed, or once the session has
  # already edited source while unarmed, later asks never arm it mid-task.
  [ -f "$SEEN" ] && exit 0
  [ -f "$DIR/edited-${SID}" ] && exit 0
  PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
  PROMPT="${PROMPT#"${PROMPT%%[![:space:]]*}"}"
  [ -n "$PROMPT" ] || exit 0
  # Openers that are not an ask leave the gate unset, so the real ask can arm it.
  case "$PROMPT" in /*|'<task-notification>'*|'<system-reminder>'*) exit 0 ;; esac
  WORDS=$(printf '%s' "$PROMPT" | wc -w | tr -d ' ')
  [ "${WORDS:-0}" -ge 5 ] || exit 0
  : > "$SEEN" 2>/dev/null || true
  # Same pattern leg-scope arms on. Those sessions are leg-scope's job.
  pat='continue (from|the|with|where)|resume (from|the)|pick up where|carry on with|reboot (file|handoff|prompt)|from the handoff|/reboot|/carryon|where (we|i|you) left off|left off (here|yesterday)|picking up (from|where)'
  printf '%s' "$PROMPT" | grep -qiE "$pat" && exit 0
  printf '%s\n' "$(printf '%s' "$PROMPT" | tr -d '\n' | cut -c1-160)" > "$ARMED" 2>/dev/null || true
  log armed
  find "$DIR" -name '*-*' -mtime +14 -delete 2>/dev/null || true
  echo "<system-reminder>restate-gate: before your first source edit, say back in ONE line what the user asked for, in his words, including scope (which thing, how many, what done looks like). Misread requests are the top friction in his insights report. Record it with: echo \"asked-for: <the one line>\"</system-reminder>"
  ;;
--record)
  [ -f "$ARMED" ] || exit 0
  [ -f "$STATED" ] && exit 0
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
  case "$CMD" in *asked-for:*) ;; *) exit 0 ;; esac
  # Cut at the LAST copy of the quote that opened the string, so an apostrophe
  # ("don't"), an arrow ("a -> b") or a shell tail ("&& git status") inside or
  # after the restatement neither cuts it short nor leaks into it.
  PRE="${CMD%%asked-for:*}"; Q="${PRE: -1}"
  BODY="${CMD#*asked-for:}"
  case "$Q" in '"'|"'") BODY="${BODY%"$Q"*}" ;; *) BODY=$(printf '%s' "$BODY" | head -1) ;; esac
  BODY=$(printf '%s' "$BODY" | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  WORDS=$(printf '%s' "$BODY" | wc -w | tr -d ' ')
  [ "${#BODY}" -ge 15 ] && [ "${WORDS:-0}" -ge 3 ] || exit 0
  printf '%s\n' "$BODY" > "$STATED" 2>/dev/null || true
  log stated
  ;;
--gate)
  # Subagents carry the parent's session id. They never saw the ask, so the
  # block belongs to the main session only.
  AGENT=$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)
  [ -n "$AGENT" ] && exit 0
  if [ ! -f "$ARMED" ]; then
    # Remember that work started unarmed, so a later ask cannot arm mid-task.
    : > "$DIR/edited-${SID}" 2>/dev/null || true
    exit 0
  fi
  [ -f "$PASSED" ] && exit 0
  if [ -f "$STATED" ]; then : > "$PASSED" 2>/dev/null || true; exit 0; fi
  FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
  # Source files only, same list as leg-scope. Notes and docs are not the risk.
  case "$FILE" in
    */handoffs/*|*REBOOT*|*HANDOFF*|*SESSION_NOTES*|*.claude/state/*) exit 0 ;;
    *.md|*.txt|*.rst|*.json|*.lock|*.env*|*.log|*.csv) exit 0 ;;
  esac
  case "$FILE" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.rb|*.go|*.rs|*.java|*.cs|*.php|*.sh|*.mts) ;;
    *.css|*.scss|*.sass|*.less|*.vue|*.svelte|*.html|*.sql|*.yaml|*.yml) ;;
    *) exit 0 ;;
  esac
  ASK=$(head -1 "$ARMED" 2>/dev/null || true)
  # Block once, then stand down, so it can never become noise. mkdir is atomic,
  # so parallel edits produce one block between them, not one each.
  mkdir "$DIR/claim-${SID}" 2>/dev/null || exit 0
  : > "$PASSED" 2>/dev/null || true
  log blocked
  cat >&2 <<MSG
[restate-gate] BLOCKED once. No restatement of the ask yet.

About to edit: ${FILE:-(a file)}
The ask began: ${ASK:-(unknown)}

Misread requests are the top friction in the user's insights report. Say back what
you think he asked for, in his words, with the scope (which thing, how many,
what done looks like). If you are unsure which of two things he meant, ask him
instead of picking one.

  echo "asked-for: <the one line>"

The gate has now stood down for this session, so the retry goes through.
MSG
  exit 2
  ;;
esac
exit 0
