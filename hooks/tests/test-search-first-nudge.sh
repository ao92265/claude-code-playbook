#!/bin/bash
# search-first-nudge.sh: first lookup-shaped Bash call nudges toward Grep/Glob/Read, the 6th nudges to a subagent.
source "$(dirname "$0")/lib.sh"
H=search-first-nudge.sh
b() { jq -nc --arg c "$1" --arg s "${2:-s1}" '{tool_input:{command:$c},session_id:$s}'; }

run $H "$(b 'grep -r foo src/')";         expect "grep exits 0" 0
expect_has "1st lookup nudges to Grep" "$OUT" "Prefer Grep"
run $H "$(b 'grep -r foo src/')"
expect_lacks "2nd lookup silent" "$OUT" "search-first"
run $H "$(b 'rg bar')"; run $H "$(b 'ag baz')"; run $H "$(b 'ack qux')"
expect_lacks "5th lookup silent" "$OUT" "search-first"
run $H "$(b 'grep again')"
expect_has "6th lookup suggests a subagent" "$OUT" "6 lookups"
run $H "$(b 'grep seventh')"
expect_lacks "7th lookup silent" "$OUT" "search-first"

run $H "$(b "find . -name '*.ts'" s2)"
expect_has "find -name nudges to Glob" "$OUT" "Glob"
run $H "$(b 'cat notes.txt' s3)"
expect_has "bare cat nudges to Read" "$OUT" "Prefer Read"
run $H "$(b 'cd /tmp && grep foo x' s4)"
expect_has "leading cd stripped" "$OUT" "search-first"
run $H "$(b 'FOO=1 grep foo x' s5)"
expect_has "leading env assignment stripped" "$OUT" "search-first"
run $H "$(b 'git log | grep fix' s6)"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   piped filter silent"; } || { fail=$((fail+1)); echo "FAIL piped filter silent"; }
run $H "$(b 'cat a.txt | wc -l' s7)"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   piped cat silent"; } || { fail=$((fail+1)); echo "FAIL piped cat silent"; }
run $H "$(b 'npm test' s8)"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   non-search command silent"; } || { fail=$((fail+1)); echo "FAIL non-search command silent"; }
run $H "$(b 'grep foo x' s9)" CLAUDE_SKIP_HOOKS=search-first-nudge
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   skip env silent"; } || { fail=$((fail+1)); echo "FAIL skip env silent"; }
run $H '{}';                              expect "no command exits 0" 0
finish
