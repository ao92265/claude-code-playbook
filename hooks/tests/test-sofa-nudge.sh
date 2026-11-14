#!/bin/bash
# sofa-nudge.sh: debugging prompts get a search reminder; "that worked" prompts get a share offer; else silent.
source "$(dirname "$0")/lib.sh"
H=sofa-nudge.sh
p() { jq -nc --arg p "$1" '{prompt:$p}'; }

run $H "$(p 'I get a stack trace when the server starts')"; expect "debug prompt exits 0" 0
expect_has "debug prompt nudges a search" "$OUT" "this looks like debugging"
run $H "$(p 'Why does the build fail')"
expect_has "case insensitive debug match" "$OUT" "this looks like debugging"
run $H "$(p 'that worked, thanks')"
expect_has "worked prompt offers a share" "$OUT" "confirmed a fix worked"
expect_lacks "worked prompt skips debug text" "$OUT" "this looks like debugging"
run $H "$(p 'it works now but there was an error before')"
expect_has "worked wins over debug words" "$OUT" "confirmed a fix worked"
run $H "$(p 'add a footer to the page')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   plain prompt silent"; } || { fail=$((fail+1)); echo "FAIL plain prompt silent"; }
run $H '{}';                              expect "no prompt exits 0" 0
run $H "$(p 'stack trace please')" CLAUDE_SKIP_HOOKS=sofa-nudge
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   skip env silent"; } || { fail=$((fail+1)); echo "FAIL skip env silent"; }
finish
