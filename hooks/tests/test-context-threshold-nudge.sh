#!/bin/bash
# context-threshold-nudge.sh: nudges once per tier at 50% and 75% context and by session age; silent below.
source "$(dirname "$0")/lib.sh"
H=context-threshold-nudge.sh
ST="$TD/state"; CFG="$HOME/.claude"; mkdir -p "$CFG"
tr_with() { # <input_tokens> -> transcript path
  local f="$TD/t-$1.jsonl"
  jq -nc --argjson n "$1" '{type:"assistant",message:{usage:{input_tokens:$n}}}' > "$f"; echo "$f"
}
pl() { jq -nc --arg t "$1" --arg s "$2" '{transcript_path:$t,session_id:$s}'; }
E=(OMC_CTX_STATE_DIR="$ST" CLAUDE_CONFIG_DIR="$CFG" OMC_CTX_WINDOW=200000)

run $H "$(pl "$(tr_with 40000)" a)" "${E[@]}";   expect "low context exits 0" 0
expect_lacks "low context silent" "$OUT" "CONTEXT"
run $H "$(pl "$(tr_with 110000)" b)" "${E[@]}"
expect_has "55 percent hits the 50 tier" "$OUT" "core-rules reboot threshold"
run $H "$(pl "$(tr_with 110000)" b)" "${E[@]}"
expect_lacks "same tier not repeated" "$OUT" "CONTEXT"
run $H "$(pl "$(tr_with 170000)" b)" "${E[@]}"
expect_has "75 tier fires after 50 tier" "$OUT" "PAST THE REBOOT LINE"
run $H "$(pl "$(tr_with 170000)" c)" "${E[@]}"
expect_has "other session fires on its own" "$OUT" "PAST THE REBOOT LINE"
run $H "$(pl "$(tr_with 110000)" d)" "${E[@]}" OMC_CTX_WINDOW=1000000
expect_lacks "window override changes the percentage" "$OUT" "CONTEXT"
run $H "$(pl /nonexistent e)" "${E[@]}";         expect "missing transcript exits 0" 0
run $H '';                                       expect "empty stdin exits 0" 0
run $H "$(pl "$(tr_with 170000)" f)" "${E[@]}" CLAUDE_SKIP_HOOKS=context-threshold-nudge
expect_lacks "skip env silent" "$OUT" "CONTEXT"

# session age tiers
LOW=$(tr_with 100)
run $H "$(pl "$LOW" g)" "${E[@]}" OMC_AGE_TEST_S=3000
expect_lacks "under the cap silent" "$OUT" "SESSION AGE"
run $H "$(pl "$LOW" g)" "${E[@]}" OMC_AGE_TEST_S=15000
expect_has "past cap, auto clear off" "$OUT" "Auto clear is OFF"
run $H "$(pl "$LOW" g)" "${E[@]}" OMC_AGE_TEST_S=15000
expect_lacks "age tier not repeated" "$OUT" "SESSION AGE"
mkdir -p "$CFG/state"; touch "$CFG/state/rotate-enabled"
run $H "$(pl "$LOW" h)" "${E[@]}" OMC_AGE_TEST_S=15000
expect_has "past cap, auto clear on" "$OUT" "run referee rotates"
run $H "$(pl "$LOW" i)" "${E[@]}" OMC_AGE_TEST_S=30000
expect_has "double the cap escalates" "$OUT" "WAY past"
run $H "$(pl "$LOW" j)" "${E[@]}" OMC_AGE_TEST_S=7200 OMC_SESSION_MAX_H=1
expect_has "cap override honoured" "$OUT" "SESSION AGE 2h0m"
finish
