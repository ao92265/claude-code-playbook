#!/bin/bash
# open-question.py: pins a question buried in a work prompt, nags, blocks the stop once, resolves.
source "$(dirname "$0")/lib.sh"
H="$HOOKS_DIR/open-question.py"
CFG="$HOME/.claude"
SD="$CFG/state/open-question"
oq() { # <mode> <stdin-json>
  printf '%s' "$2" | env CLAUDE_CONFIG_DIR="$CFG" python3 "$H" "$1" >"$TD/o" 2>"$TD/e"
  RC=$?; OUT=$(cat "$TD/o"); ERR=$(cat "$TD/e")
}
P() { jq -nc --arg p "$1" --arg s "${2:-s1}" '{prompt:$p,session_id:$s}'; }
S() { jq -nc --arg s "${1:-s1}" '{session_id:$s}'; }

oq --prompt "$(P 'Refactor the parser module now. Also, why is the cache slow?')"
expect "prompt exits 0" 0
expect_has "nag block printed" "$OUT" "OPEN QUESTION"
expect_has "nag quotes the question" "$OUT" "why is the cache slow?"
[[ -f "$SD/s1.json" && -f "$SD/s1.hud" ]] && { pass=$((pass+1)); echo "ok   state and hud written"; } || { fail=$((fail+1)); echo "FAIL state and hud written"; }
oq --prompt "$(P 'Carry on with the work please')"
expect_has "next turn still nags" "$OUT" "OPEN QUESTION"
oq --stop "$(S)";                          expect "unanswered question blocks stop" 2
expect_has "block names the question" "$ERR" "UNANSWERED QUESTION"
oq --stop "$(S)";                          expect "second stop passes" 0
oq --resolve "$(S)"
expect_has "resolve confirms" "$OUT" "cleared"
[[ ! -f "$SD/s1.json" ]] && { pass=$((pass+1)); echo "ok   resolve clears state"; } || { fail=$((fail+1)); echo "FAIL resolve clears state"; }
oq --stop "$(S)";                          expect "no state stop passes" 0

oq --prompt "$(P 'What time is it?' s2)"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   pure question not pinned"; } || { fail=$((fail+1)); echo "FAIL pure question not pinned"; }
oq --prompt "$(P 'Fix this \`a ? b : c\` expression in the file please' s3)"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   code ternary not pinned"; } || { fail=$((fail+1)); echo "FAIL code ternary not pinned"; }
oq --prompt "$(P '/review do the thing and also why?' s4)"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   slash command not pinned"; } || { fail=$((fail+1)); echo "FAIL slash command not pinned"; }

oq --prompt "$(P 'Do the work now. Is the build green?' s5)"
oq --stop "$(jq -nc '{session_id:"s5",stop_hook_active:true}')"
expect "stop continuation never re-blocks" 0
oq --show "$(S s5)"
expect_has "show prints question" "$OUT" "Is the build green?"
oq --show "$(S s9)"
expect_has "show with none" "$OUT" "No open question"
echo "{\"questions\":[\"old?\"],\"pure\":false,\"turn\":1,\"pinned_at\":1,\"nagged\":false}" > "$SD/s6.json"
oq --stop "$(S s6)";                       expect "expired pin does not block" 0
oq --prompt "$(P 'Hello there, just checking in.' s6)"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   expired pin dropped"; } || { fail=$((fail+1)); echo "FAIL expired pin dropped"; }
printf '' | env CLAUDE_CONFIG_DIR="$CFG" python3 "$H" --pin "is it done" >"$TD/o" 2>&1; RC=$?
expect "manual pin exits 0" 0
expect_has "manual pin appends question mark" "$(cat "$TD/o")" "is it done?"
finish
