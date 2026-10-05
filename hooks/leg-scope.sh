#!/usr/bin/env bash
# leg-scope.sh - one hook, three modes. Forces a continuation session to say what
# would finish THIS leg, before it starts editing.
#
#   --arm     UserPromptSubmit. Marks the session as a continuation.
#   --record  PostToolUse(Bash).  Stamps the stated finish line.
#   --gate    PreToolUse(Edit|Write). Blocks the first edit until one exists.
#
# Why: 55 of the 93 scored sessions are continuation or handoff work, roughly 59
# percent. It is the dominant shape of the whole corpus. The ones that land fully
# achieved tend to carry a concrete finish line for the leg ("push PR 334 and get
# the second-opinion review back"). The ones that land only mostly achieved tend
# to inherit the PROJECT's finish line instead, which no single session can reach,
# so they stop when context runs out rather than when the work is done.
#
# One sentence at the top is the entire fix. This makes it non-optional, once.
#
# Exit codes: 0 allow, 2 block (gate mode only)
# Disable: CLAUDE_SKIP_HOOKS=leg-scope
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,leg-scope,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
MODE="${1:---gate}"
INPUT=$(cat 2>/dev/null || true)
printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || exit 0

SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-'); SID=${SID:-default}
DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/leg-scope"
mkdir -p "$DIR" 2>/dev/null || exit 0
ARMED="$DIR/armed-${SID}"; STATED="$DIR/stated-${SID}"; PASSED="$DIR/passed-${SID}"

case "$MODE" in
--arm)
  PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
  [ -n "$PROMPT" ] || exit 0
  # The literal openings these sessions use. Deliberately not "continue" alone,
  # which appears in plenty of one-shot asks.
  # Explicitly continuation-shaped only. 'finish the login form validation' and
  # 'finish off the CSS' are ordinary one-shot asks, and arming a BLOCKING gate
  # on them blocked every edit in the session.
  pat='continue (from|the|with|where)|resume (from|the)|pick up where|carry on with|reboot (file|handoff|prompt)|from the handoff|/reboot|/carryon|where (we|i|you) left off|left off (here|yesterday)|picking up (from|where)'
  printf '%s' "$PROMPT" | grep -qiE "$pat" || exit 0
  [ -f "$STATED" ] && exit 0
  printf '%s\n' "$(printf '%s' "$PROMPT" | tr -d '\n' | cut -c1-160)" > "$ARMED" 2>/dev/null || true
  echo "<system-reminder>leg-scope: this is a continuation session. Before editing anything, state in ONE line what would make THIS session complete, as distinct from what would make the project complete. Continuation work is 59 percent of your corpus and the sessions that only 'mostly' land are the ones that inherited the project's finish line instead of setting their own. Record it with: echo \"leg-done: <the one line>\"</system-reminder>"
  ;;
--record)
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
  [ -n "$CMD" ] || exit 0
  LINE=$(printf '%s' "$CMD" | grep -oiE 'leg-done:[^"'"'"']*' | head -1 || true)
  [ -n "$LINE" ] || exit 0
  # A finish line has to say something. The old bar was 6 characters, which
  # "ship it" cleared, so it stopped only the laziest token. Three words and 15
  # characters is still trivial to satisfy honestly and hard to satisfy lazily.
  BODY=$(printf '%s' "$LINE" | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  WORDS=$(printf '%s' "$BODY" | wc -w | tr -d ' ')
  [ "${#BODY}" -ge 15 ] && [ "${WORDS:-0}" -ge 3 ] || exit 0
  printf 'at=%s\nline=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BODY" > "$STATED" 2>/dev/null || true
  find "$DIR" -type f -mtime +14 -delete 2>/dev/null || true
  ;;
--gate)
  [ -f "$ARMED" ] || exit 0
  [ -f "$PASSED" ] && exit 0
  if [ -f "$STATED" ]; then : > "$PASSED" 2>/dev/null || true; exit 0; fi
  FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
  # Only real source work. The gate had no file filter, so once armed it blocked
  # READMEs, notes and dotfiles alike, none of which are the thing worth pausing.
  case "$FILE" in
    */handoffs/*|*REBOOT*|*HANDOFF*|*SESSION_NOTES*|*.claude/state/*) exit 0 ;;
    *.md|*.txt|*.rst|*.json|*.lock|*.env*|*.log|*.csv) exit 0 ;;
  esac
  case "$FILE" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.rb|*.go|*.rs|*.java|*.cs|*.php|*.sh|*.mts) ;;
    *.css|*.scss|*.sass|*.less|*.vue|*.svelte|*.html|*.sql|*.yaml|*.yml) ;;
    *) exit 0 ;;
  esac
  WHY=$(head -1 "$ARMED" 2>/dev/null || true)
  # Block once, then stand down. There is no per-Edit escape to offer, so a gate
  # that repeats is a gate that has to be disabled.
  : > "$PASSED" 2>/dev/null || true
  cat >&2 <<MSG
[leg-scope] BLOCKED. Continuation session with no finish line for this leg.

About to edit: ${FILE:-(a file)}
Armed by: ${WHY:-a continuation-shaped prompt}

Continuation and handoff work is 55 of your 93 scored sessions. The pattern that
separates the ones that fully land from the ones that only mostly land is not
effort, it is whether the session set a finish line it could actually reach.
Inheriting the project's finish line guarantees the session ends on context
exhaustion instead of completion.

State it, then this unblocks for the rest of the session:

  echo "leg-done: <what makes THIS session complete, in one line>"

Good: leg-done: push PR 334 and get the second-opinion review back green
Bad:  leg-done: finish the theme work        (that is the project, not the leg)

This gate has now stood down for the rest of the session, so the retry goes
through either way. It fires once so it cannot become noise.
MSG
  exit 2
  ;;
esac
exit 0
