#!/usr/bin/env bash
# status-shape-gate.sh -- Stop hook. Enforces rule 6 (STATUS replies = did/doing/
# need, nothing else) by blocking, not nudging.
#
# Why: rule 6 already lives in register-gate.py's per-prompt injection, but that
# is a nudge that decays with context (see rule-drift-detector memory: register
# compliance drops as context fills). The verbose per-pane recaps in the 2026-09-09
# screenshot happened in long, high-context sessions exactly where nudges rot.
# This makes the shape a hard gate on Stop, like verify-gate does for green tests.
#
# Trigger: only fires when the user's last prompt looks like a progress check-in
# ("keep going", "status", "how's it going", etc.) - a real status turn, not every
# reply. On that trigger, if the assistant's final message is long AND reads like
# a narrative (multiple paragraphs / many bullet lines) rather than a tight
# did/doing/need block, block once with a rewrite instruction.
#
# Disable: CLAUDE_SKIP_HOOKS=status-shape-gate
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,status-shape-gate,*) exit 0 ;; esac

set -u
export LC_ALL=${LC_ALL:-en_US.UTF-8}
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat 2>/dev/null || true)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null || true)
[ -z "$transcript" ] && exit 0
[ -f "$transcript" ] || exit 0

# Only run once per turn: if we already blocked this exact transcript length, don't loop.
stop_hook_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || true)
[ "$stop_hook_active" = "true" ] && exit 0

last_user=$(tail -n 400 "$transcript" 2>/dev/null \
  | jq -rs '[.[] | select(.type=="user")] | last | .message.content
            | if type=="array" then map(select(.type=="text") // .text?) | join(" ") else . end' \
     2>/dev/null || true)
[ -z "$last_user" ] && exit 0

# Heuristic: is this a check-in / progress prompt, not a fresh substantive ask?
shopt -s nocasematch 2>/dev/null || true
is_status_prompt=0
case "$last_user" in
  *"keep going"*|*"status"*|*"how's it going"*|*"hows it going"*|*"progress"*|*"where are we"*|*"any update"*|*"check in"*|*"still going"*|*"any progress"*)
    is_status_prompt=1 ;;
esac
[ "$is_status_prompt" -eq 0 ] && exit 0

last_reply=$(tail -n 200 "$transcript" 2>/dev/null \
  | jq -rs '[.[] | select(.type=="assistant")] | last | .message.content
            | if type=="array" then map(select(.type=="text") | .text) | join("\n") else . end' \
     2>/dev/null || true)
[ -z "$last_reply" ] && exit 0

WORDS=$(printf '%s' "$last_reply" | wc -w | tr -d ' ')
LINES=$(printf '%s' "$last_reply" | grep -c . )

# Rule 6 budget: a real did/doing/need status is a handful of short lines.
# Anything past ~70 words or ~8 non-blank lines on a status turn is narrative.
if [ "$WORDS" -gt 70 ] || [ "$LINES" -gt 8 ]; then
  echo "status-shape-gate: this was a status check-in (\"$last_user\") but the reply ran $WORDS words / $LINES lines." >&2
  echo "Rule 6: status replies are three parts only - what I did, what I'm doing, what I need from him. No findings, no diagnosis, no reasoning. Rewrite it that short now." >&2
  exit 2
fi

exit 0
