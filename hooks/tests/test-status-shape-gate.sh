#!/bin/bash
# status-shape-gate.sh: on a progress check-in, a long narrative reply blocks the stop (2); short replies pass.
source "$(dirname "$0")/lib.sh"
H=status-shape-gate.sh
mk() { # <user prompt> <assistant text> -> transcript path
  local f="$TD/t$RANDOM.jsonl"
  { jq -nc --arg u "$1" '{type:"user",message:{content:$u}}'
    jq -nc --arg a "$2" '{type:"assistant",message:{content:[{type:"text",text:$a}]}}'; } > "$f"; echo "$f"
}
pl() { jq -nc --arg t "$1" '{transcript_path:$t}'; }
SHORT=$'Did: fixed the parser.\nDoing: running checks.\nNeed: nothing.'
LONGW=$(printf 'word %.0s' $(seq 1 90))
LONGL=$(printf 'line\n%.0s' $(seq 1 12))

run $H "$(pl "$(mk 'keep going' "$SHORT")")";   expect "short status reply passes" 0
run $H "$(pl "$(mk 'Keep going' "$LONGW")")";   expect "long words on check-in blocks" 2
expect_has "message names the rule" "$ERR" "Rule 6"
run $H "$(pl "$(mk 'any update?' "$LONGL")")";  expect "many lines on check-in blocks" 2
run $H "$(pl "$(mk 'write me a parser' "$LONGW")")"; expect "non-status prompt passes" 0
run $H "$(jq -nc --arg t "$(mk 'status' "$LONGW")" '{transcript_path:$t,stop_hook_active:true}')"
expect "already blocked once passes" 0
run $H "$(pl "$(mk 'status' "$LONGW")")" CLAUDE_SKIP_HOOKS=status-shape-gate
expect "skip env passes" 0
run $H '{"transcript_path":"/nonexistent"}';    expect "missing transcript passes" 0
run $H '{}';                                    expect "no transcript path passes" 0
finish
