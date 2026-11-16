#!/bin/bash
# feedback-marker.sh: a prompt starting with :) or :( injects instructions and logs the verdict.
source "$(dirname "$0")/lib.sh"
H=feedback-marker.sh
LOG="$HOME/.claude/feedback.jsonl"; mkdir -p "$HOME/.claude"
p() { jq -nc --arg p "$1" '{prompt:$p,session_id:"sess9"}'; }

run $H "$(p ':)')";                     expect "thumbs up exits 0" 0
expect_has "up block injected" "$OUT" "user approved"
run $H "$(p ':-( too verbose')"
expect_has "down block injected" "$OUT" "user rejected"
run $H "$(p 'nice :) work')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   mid-sentence emoticon silent"; } || { fail=$((fail+1)); echo "FAIL mid-sentence emoticon silent"; }
run $H "$(p 'hello')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   plain prompt silent"; } || { fail=$((fail+1)); echo "FAIL plain prompt silent"; }
LASTL=$(tail -n 2 "$LOG" | head -n 1)
[[ $(wc -l < "$LOG") -eq 2 ]] && { pass=$((pass+1)); echo "ok   only markers logged"; } || { fail=$((fail+1)); echo "FAIL only markers logged"; }
expect_has "log has the note" "$(tail -n 1 "$LOG")" '"note":"too verbose"'
expect_has "log has verdict down" "$(tail -n 1 "$LOG")" '"verdict":"down"'
expect_has "log has verdict up" "$LASTL" '"verdict":"up"'
expect_has "log has session" "$LASTL" 'sess9'
run $H '';                              expect "empty stdin exits 0" 0
run $H "$(p ':)')" CLAUDE_SKIP_HOOKS=feedback-marker
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   skip env silent"; } || { fail=$((fail+1)); echo "FAIL skip env silent"; }
finish
