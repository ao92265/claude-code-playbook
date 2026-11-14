#!/bin/bash
# correction-detect.sh: prompts that read as a verdict on the last reply inject a root-cause block and log it.
source "$(dirname "$0")/lib.sh"
H=correction-detect.sh
LOG="$HOME/.claude/feedback.jsonl"; mkdir -p "$HOME/.claude"
p() { jq -nc --arg p "$1" '{prompt:$p,session_id:"s1"}'; }
yes() { run $H "$(p "$1")"; expect_has "$2" "$OUT" "CORRECTION DETECTED ($3)"; }
no()  { run $H "$(p "$1")"; expect_lacks "$2" "$OUT" "CORRECTION DETECTED"; }
LONG=$(printf 'x%.0s' $(seq 1 200))

yes "No, do it the other way" "opening negation" "opening negation"
yes "wrong file" "direct contradiction" "direct contradiction"
yes "tldr" "wholesale rejection" "wholesale rejection"
yes "you missed the second item" "skipped item" "pointing at what was skipped"
yes "i said use the small one" "terse restate" "restating the original ask"
yes "stop adding comments" "told to stop" "told to stop doing something"
yes "explain in plain english" "register complaint" "register too technical"
expect_has "register complaint names the fix" "$OUT" "FIX SHAPE"
yes "that was too long" "heavy reply" "response too heavy"
yes "it still broken" "claimed working" "claimed working, was not"
yes "the em dash is back" "prose tells" "prose tells"
no "please add a login page" "normal request silent"
no "I said earlier $LONG" "long restate is context" 
no "$LONG too long" "long prompt skips tier 2"
no ":( no" "emoticon left to feedback-marker"
yes "nope. $LONG" "tier 1a fires at any length" "opening negation"
run $H "$(p "wrong")"; expect "exits 0" 0
n=$(grep -c '"source":"auto"' "$LOG")
[[ "$n" -ge 10 ]] && { pass=$((pass+1)); echo "ok   matches are logged"; } || { fail=$((fail+1)); echo "FAIL matches are logged (got $n)"; }
before=$(wc -l < "$LOG"); run $H "$(p "add a button")"
[[ $(wc -l < "$LOG") -eq $before ]] && { pass=$((pass+1)); echo "ok   non-match not logged"; } || { fail=$((fail+1)); echo "FAIL non-match not logged"; }
run $H "$(p wrong)" CLAUDE_SKIP_HOOKS=correction-detect
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   skip env silent"; } || { fail=$((fail+1)); echo "FAIL skip env silent"; }
finish
