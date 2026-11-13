#!/bin/bash
# chrome-ref-first.sh: first pixel-coordinate click gets one nudge; read_page/find disarm it.
source "$(dirname "$0")/lib.sh"
H=chrome-ref-first.sh
c() { jq -nc --arg t "$1" --arg sid "$2" --argjson i "$3" '{tool_name:$t,session_id:$sid,tool_input:$i}'; }
CLICK='{"action":"left_click","coordinate":[10,20]}'
CT=mcp__claude-in-chrome__computer

run $H "$(c $CT s1 "$CLICK")"
expect "coordinate click: exit 0" 0; expect_has "coordinate click nudged" "$OUT" "additionalContext"
run $H "$(c $CT s1 "$CLICK")"
expect_lacks "second click not nudged again" "$OUT" "additionalContext"
run $H "$(c $CT s2 '{"action":"left_click","ref":"ref_1"}')"
expect_lacks "click by ref not nudged" "$OUT" "additionalContext"
run $H "$(c $CT s7 '{"action":"left_click","ref":"r1","coordinate":[1,2]}')"
expect_lacks "ref plus coordinate not nudged" "$OUT" "additionalContext"
run $H "$(c $CT s2 '{"action":"screenshot"}')"
expect_lacks "screenshot not nudged" "$OUT" "additionalContext"
run $H "$(c mcp__claude-in-chrome__read_page s3 '{}')"
run $H "$(c $CT s3 "$CLICK")"
expect_lacks "click after read_page not nudged" "$OUT" "additionalContext"
run $H "$(c mcp__claude-in-chrome__find s4 '{}')"
run $H "$(c $CT s4 "$CLICK")"
expect_lacks "click after find not nudged" "$OUT" "additionalContext"
run $H "$(c Bash s5 "$CLICK")"
expect_lacks "other tools ignored" "$OUT" "additionalContext"
run $H "$(c $CT s6 "$CLICK")" CLAUDE_SKIP_HOOKS=chrome-ref-first
expect_lacks "skip env honoured" "$OUT" "additionalContext"
finish
