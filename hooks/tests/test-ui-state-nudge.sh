#!/bin/bash
# ui-state-nudge.sh: visual-QA comparison prompts inject the assert-state rule and arm the state gate.
source "$(dirname "$0")/lib.sh"
H=ui-state-nudge.sh
CFG="$HOME/.claude"
p() { jq -nc --arg p "$1" --arg s "${2:-s1}" '{prompt:$p,session_id:$s}'; }

run $H "$(p 'check the dark mode parity' sa)" CLAUDE_CONFIG_DIR="$CFG"; expect "visual prompt exits 0" 0
expect_has "injects the assert-state rule" "$OUT" "ASSERT THE ACTIVE STATE FIRST"
[[ -f "$CFG/state/ui-state/armed-sa" ]] && { pass=$((pass+1)); echo "ok   gate armed for the session"; } || { fail=$((fail+1)); echo "FAIL gate armed for the session"; }
expect_has "armed file records the prompt" "$(cat "$CFG/state/ui-state/armed-sa" 2>/dev/null)" "dark mode parity"
run $H "$(p 'compare the screenshot to the mock' sb)" CLAUDE_CONFIG_DIR="$CFG"
expect_has "compare screenshot matches" "$OUT" "ASSERT THE ACTIVE STATE FIRST"
run $H "$(p 'the sidebar toggle is broken, fix it' sc)" CLAUDE_CONFIG_DIR="$CFG"
expect_lacks "bare noun does not match" "$OUT" "ASSERT"
[[ ! -f "$CFG/state/ui-state/armed-sc" ]] && { pass=$((pass+1)); echo "ok   no arming on a non-match"; } || { fail=$((fail+1)); echo "FAIL no arming on a non-match"; }
run $H "$(p 'add a database index' sd)" CLAUDE_CONFIG_DIR="$CFG"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   non-visual prompt silent"; } || { fail=$((fail+1)); echo "FAIL non-visual prompt silent"; }
run $H "$(p 'dark mode parity' se)" CLAUDE_CONFIG_DIR="$CFG" CLAUDE_SKIP_HOOKS=ui-state-nudge
[[ -z "$OUT" && ! -f "$CFG/state/ui-state/armed-se" ]] && { pass=$((pass+1)); echo "ok   skip env silent and unarmed"; } || { fail=$((fail+1)); echo "FAIL skip env silent and unarmed"; }
run $H '{}';                              expect "no prompt exits 0" 0
finish
