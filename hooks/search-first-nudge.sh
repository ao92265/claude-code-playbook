#!/usr/bin/env bash
# search-first-nudge.sh — PreToolUse(Bash). Advisory, never blocks.
#
# Why: on the calibrated myinsights scorecard (2026-08-18) the two weakest factors
# were tool reliability (58/100) and delegation leverage (30/100). Both trace to the
# same habit: Bash is 3,783 of ~7,373 tool calls, and "Command Failed" is 190 of 368
# errors. Most of those Bash calls are LOOKING for something, which Grep/Glob/Read do
# without a shell, without quoting bugs, and without a non-zero exit on no-match.
#
# Two nudges, both once per session, then silent:
#   1st search-shaped Bash call  -> use the structured search tools instead
#   6th                          -> this is a sweep, hand it to a cheap subagent
#
# Only fires when the SEARCH IS THE COMMAND. `git log | grep x` filters output of a
# real command and is left alone; `grep -r foo src/` is the case worth catching.
#
# Disable: CLAUDE_SKIP_HOOKS=search-first-nudge  (OMC_SKIP_HOOKS is the legacy alias)
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,search-first-nudge,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$CMD" ] && exit 0
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-'); SID=${SID:-default}

# First command of the pipeline only: strip leading whitespace, env assignments and
# a leading "cd X &&" so the check sees the verb the user actually ran.
HEAD=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]+//; s/^cd [^&|;]+(&&|;)[[:space:]]*//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)+//')
VERB=$(printf '%s' "$HEAD" | awk '{print $1}')

SHAPE=""
case "$VERB" in
  grep|egrep|fgrep|rg|ag|ack) SHAPE="content" ;;
  find)  printf '%s' "$HEAD" | grep -qE ' -(name|iname|path|regex) ' && SHAPE="files" ;;
  ls)    printf '%s' "$HEAD" | grep -qE '^ls .*-[a-zA-Z]*R' && SHAPE="files" ;;
  cat|head|tail)
         # A bare read of one file. Piped or redirected reads are real plumbing.
         printf '%s' "$HEAD" | grep -qE '[|><]' || SHAPE="read" ;;
esac
[ -z "$SHAPE" ] && exit 0

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR" 2>/dev/null || true
COUNTF="$STATE_DIR/searchnudge-${SID}"
N=$(cat "$COUNTF" 2>/dev/null || echo 0)
case "$N" in ''|*[!0-9]*) N=0 ;; esac
N=$((N + 1))
printf '%s' "$N" > "$COUNTF" 2>/dev/null || true

if [ "$N" -eq 1 ]; then
  case "$SHAPE" in
    content) ALT="Grep (regex over file contents, no shell quoting, no exit 1 on no-match)" ;;
    files)   ALT="Glob (path patterns) or Grep" ;;
    read)    ALT="Read (line-numbered, handles large files, and the harness tracks what you have read)" ;;
  esac
  echo "<system-reminder>search-first: that Bash call is a lookup. Prefer ${ALT}. Shell search is where the error tail comes from (190 of 368 recorded tool errors were failed commands), and it costs a round trip the structured tools do not. Bash stays right for RUNNING things: builds, tests, git, scripts.</system-reminder>"
elif [ "$N" -eq 6 ]; then
  echo "<system-reminder>search-first: 6 lookups this session, so this is a sweep, not a glance. Hand broad exploration to a subagent instead of paging it through main context: Explore for a general sweep. Pass model=haiku for search and extraction (require-agent-model.sh enforces an explicit model), cap the reply at a verdict plus 5 bullets, and keep this context for the judgment work.</system-reminder>"
fi
exit 0
