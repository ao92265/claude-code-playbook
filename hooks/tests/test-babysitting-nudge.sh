#!/bin/bash
# babysitting-nudge.sh: 3 bare continues in a row nudge; other prompts reset; aliases and probe-first lines.
source "$(dirname "$0")/lib.sh"
H=babysitting-nudge.sh
p() { jq -nc --arg p "$1" --arg s "${2:-s1}" '{prompt:$p,session_id:$s}'; }

run $H "$(p continue)";                 expect "1st continue exits 0" 0
expect_lacks "1st continue silent" "$OUT" "manually continued"
run $H "$(p 'Keep going!')";            expect "2nd continue exits 0" 0
expect_lacks "2nd continue silent" "$OUT" "manually continued"
run $H "$(p retry)"
expect_has "3rd continue nudges" "$OUT" "manually continued 3x"
run $H "$(p continue)"
expect_lacks "counter reset after nudge" "$OUT" "manually continued"
run $H "$(p continue)"; run $H "$(p 'real work please')"
run $H "$(p continue)"; run $H "$(p continue)"
expect_lacks "substantive prompt resets streak" "$OUT" "manually continued"
run $H "$(p continue s2)"; run $H "$(p continue s2)"; run $H "$(p continue s3)"
expect_lacks "sessions counted separately" "$OUT" "manually continued"
run $H "$(p 'commit this')"
expect_has "commit alias routes to plugin" "$OUT" "commit-commands:commit"
run $H "$(p 'ship it')"
expect_has "push alias routes to plugin" "$OUT" "commit-push-pr"
run $H "$(p 'set up OAuth for the app')"
expect_has "external dependency gets probe-first" "$OUT" "Probe-first"
run $H "$(p 'rename a variable')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   plain prompt silent"; } || { fail=$((fail+1)); echo "FAIL plain prompt silent"; }
run $H '{"prompt":""}';                 expect "empty prompt exits 0" 0
run $H "$(p continue)" CLAUDE_SKIP_HOOKS=babysitting-nudge; expect "skip env exits 0" 0
run $H "$(p 'commit this')" CLAUDE_SKIP_HOOKS=babysitting-nudge
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   skip env silent"; } || { fail=$((fail+1)); echo "FAIL skip env silent"; }
finish
