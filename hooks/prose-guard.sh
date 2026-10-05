#!/usr/bin/env bash
# prose-guard.sh -- PostToolUse(Edit|Write) hook. Catches em/en dashes in prose
# files at the moment they are written.
#
# Why: the "always de-slop drafts" rule lived in an @-imported rules file and in
# the anti-ai-prose skill. Neither fires reliably. @-imported rules go cold at
# high context (see the rules-must-be-hooks memory), and a skill only runs when
# the model chooses to invoke it. The em dash kept landing in drafts anyway.
# answer-shape-nudge.sh now carries the rule for chat replies; this covers the
# files. Two layers because the failure was total, not occasional.
#
# Only inspects the text THIS call wrote (tool_input.content / new_string), not
# the whole file. Editing one line of an old doc must not nag about dashes that
# were already there.
#
# PostToolUse exit 2 surfaces to the model without blocking the already-landed
# write, so it gets fixed in the same turn. Same contract as hook-edit-smoke.sh.
#
# Disable: CLAUDE_SKIP_HOOKS=prose-guard
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,prose-guard,*) exit 0 ;; esac

set -u
export LC_ALL=${LC_ALL:-en_US.UTF-8}

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[ -z "$FILE_PATH" ] && exit 0

# Prose only. Code comments are covered by review, not by this.
case "$FILE_PATH" in
  *.md|*.markdown|*.txt) ;;
  *) exit 0 ;;
esac

# Hook and script headers legitimately contain em dashes in their own prose, and
# rewriting them would churn files nobody reads as prose.
case "$FILE_PATH" in
  "$HOME/.claude/hooks/"*|"$HOME/.claude/scripts/"*) exit 0 ;;
esac

# Only the newly written text. Covers Write (.content), Edit (.new_string) and
# any multi-edit shape (.edits[].new_string).
NEW=$(printf '%s' "$INPUT" | jq -r '
  [ .tool_input.content?, .tool_input.new_string?, (.tool_input.edits[]?.new_string) ]
  | map(select(type == "string")) | join("\n")
' 2>/dev/null || true)
[ -z "$NEW" ] && exit 0

HITS=$(printf '%s' "$NEW" | grep -n -- '[—–]' 2>/dev/null | head -5)
[ -z "$HITS" ] && exit 0

COUNT=$(printf '%s' "$NEW" | grep -o -- '[—–]' 2>/dev/null | wc -l | tr -d ' ')

{
  echo "prose-guard: $COUNT em/en dash(es) in the text just written to $FILE_PATH."
  echo "Rewrite those spans now: full stop, comma, colon, or brackets. Do not leave them for a later pass."
  printf '%s\n' "$HITS" | cut -c1-160
} >&2

exit 2
