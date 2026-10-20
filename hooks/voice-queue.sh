#!/usr/bin/env bash
# voice-queue.sh - records which sessions are waiting on the user, for the voice
# conductor (a voice front end). Usage: voice-queue.sh stop|notification|prompt
#   stop          turn ended: entry kind "finished" with the last reply
#   notification  permission prompt: "permission"; plan approval: "menu" (keyboard only);
#                 idle ping keeps stop text, or takes the last reply from the transcript
#   prompt        he typed something: clear the entry
# State: ~/.claude/state/voice-queue/<session>.json   Disable: CLAUDE_SKIP_HOOKS=voice-queue
case ",${CLAUDE_SKIP_HOOKS:-}," in *,voice-queue,*) exit 0 ;; esac
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
EVENT="${1:-}"
DIR="${VOICE_QUEUE_DIR:-$HOME/.claude/state/voice-queue}"
INPUT=$(cat 2>/dev/null || true)
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$SESSION" ] || exit 0
mkdir -p "$DIR" 2>/dev/null || exit 0
FILE="$DIR/$SESSION.json"

if [ "$EVENT" = "prompt" ]; then rm -f "$FILE"; exit 0; fi

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
PROJECT=$(basename "${CWD:-unknown}")
last_reply() {
  local t; t=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
  [ -f "$t" ] || return 0
  tail -n 200 "$t" | jq -rs '[.[] | select(.type=="assistant")
    | .message.content[]? | select(.type=="text") | .text] | last // empty' 2>/dev/null | oneline
}
# One line, the LAST 400 characters: Claude puts its question at the end. jq counts characters, not bytes.
oneline() { tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | jq -Rrs 'rtrimstr("\n") | .[-400:]'; }

if [ "$EVENT" = "stop" ]; then
  KIND=finished
  TEXT=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // empty' | oneline)
  [ -n "$TEXT" ] || TEXT=$(last_reply)
elif [ "$EVENT" = "notification" ]; then
  MSG=$(printf '%s' "$INPUT" | jq -r '.message // empty' | oneline)
  case "$MSG" in
    *ermission*) KIND=permission; TEXT="$MSG" ;;
    *pproval*) KIND=menu; TEXT="$MSG" ;;
    *) [ -f "$FILE" ] && exit 0; KIND=waiting; TEXT=$(last_reply); [ -n "$TEXT" ] || TEXT="$MSG" ;;
  esac
else
  exit 0
fi

TMP="$FILE.$$"
jq -n --arg s "$SESSION" --arg p "$PROJECT" --arg k "$KIND" --arg t "$TEXT" \
  --argjson ts "$(date +%s)" '{session:$s, project:$p, kind:$k, text:$t, ts:$ts}' \
  > "$TMP" && mv -f "$TMP" "$FILE"
exit 0
