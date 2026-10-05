#!/usr/bin/env bash
# chrome-ref-first.sh — PreToolUse(mcp__claude-in-chrome__*). Advisory, never blocks.
#
# Why: driving Chrome by screenshot and pixel guess is slow and misclicks. The
# extension already exposes element references: read_page or find returns a ref,
# and computer clicks by ref land first time. Source: a TikTok tip reviewed
# 2026-09-28, and it matches how the tools are built.
#
# read_page / find  -> record that refs are in play this session, stay silent
# computer click/type with a coordinate and no ref, before any read_page/find
#                   -> nudge once per session, then silent
#
# Disable: CLAUDE_SKIP_HOOKS=chrome-ref-first
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,chrome-ref-first,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-'); SID=${SID:-default}

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR" 2>/dev/null || true
FLAG="$STATE_DIR/chromeref-${SID}"

case "$TOOL" in
  mcp__claude-in-chrome__read_page|mcp__claude-in-chrome__find)
    : > "$FLAG" 2>/dev/null || true
    exit 0 ;;
  mcp__claude-in-chrome__computer) ;;
  *) exit 0 ;;
esac

[ -e "$FLAG" ] && exit 0

ACTION=$(printf '%s' "$INPUT" | jq -r '.tool_input.action // empty' 2>/dev/null || true)
HAS_COORD=$(printf '%s' "$INPUT" | jq -r 'if .tool_input.coordinate then "y" else "" end' 2>/dev/null || true)
HAS_REF=$(printf '%s' "$INPUT" | jq -r 'if .tool_input.ref then "y" else "" end' 2>/dev/null || true)

case "$ACTION" in
  left_click|right_click|double_click|triple_click|type|scroll|left_click_drag) ;;
  *) exit 0 ;;
esac
[ -n "$HAS_COORD" ] && [ -z "$HAS_REF" ] || exit 0

# Once per session: set the flag so the next coordinate click stays quiet.
: > "$FLAG" 2>/dev/null || true
MSG="chrome-ref-first: that is a pixel-coordinate click. Call read_page (filter interactive) or find first to get the element ref, then click or type by ref. Screenshots are for checking the result, not for finding the target."
jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
exit 0
