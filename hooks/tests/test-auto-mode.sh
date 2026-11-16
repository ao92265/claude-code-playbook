#!/bin/bash
# auto-mode.py: when auto is on, judgment questions are denied (escape hatch on re-ask), turns end with a push, danger passes.
source "$(dirname "$0")/lib.sh"
H="$HOOKS_DIR/auto-mode.py"
CFG="$HOME/.claude"
SD="$CFG/state/auto"
am() { # <mode> <stdin-json> [args...]
  local m="$1" in="$2"; shift 2
  printf '%s' "$in" | env CLAUDE_CONFIG_DIR="$CFG" python3 "$H" "$m" "$@" >"$TD/o" 2>"$TD/e"
  RC=$?; OUT=$(cat "$TD/o"); ERR=$(cat "$TD/e")
}
S() { jq -nc --arg s "$1" '{session_id:$s}'; }
Q() { jq -nc --arg s "$1" --arg q "$2" '{session_id:$s,tool_input:{questions:[{question:$q,options:["a","b"]}]}}'; }
tr_for() { jq -nc --arg a "$1" '{type:"assistant",message:{content:[{type:"text",text:$a}]}}' > "$TD/tr-$2.jsonl"; echo "$TD/tr-$2.jsonl"; }

# off: nothing happens
am --gate "$(Q a1 'Which colour scheme should the page use?')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   gate allows when off"; } || { fail=$((fail+1)); echo "FAIL gate allows when off"; }
am --prompt "$(S a1)"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   prompt silent when off"; } || { fail=$((fail+1)); echo "FAIL prompt silent when off"; }
am --show "$(S a1)";                       expect_has "show reports off" "$OUT" "auto is OFF"

am --on "$(S a1)";                         expect_has "on confirms" "$OUT" "auto ON (here)"
am --gate "$(Q a1 'Which colour scheme should the page use?')"
expect_has "judgment question denied" "$OUT" '"permissionDecision": "deny"'
am --gate "$(Q a1 'Which colour scheme should the page use?')"
expect_has "identical re-ask same turn still denied" "$OUT" "deny"
am --prompt "$(S a1)"
expect_has "prompt reminds while on" "$OUT" "AUTO MODE ON"
am --gate "$(Q a1 'Which colour scheme should the page use?')"
expect_lacks "re-ask on a later turn allowed" "$OUT" "deny"
am --gate "$(Q a1 'Should I deploy this to production now?')"
expect_lacks "deploy question allowed through" "$OUT" "deny"
am --gate "$(Q a1 'Should I send this message to the client?')"
expect_lacks "outward question allowed through" "$OUT" "deny"
am --gate "$(Q a1 'Is the charge of $50 acceptable?')"
expect_lacks "money question allowed through" "$OUT" "deny"
am --gate '{"session_id":"a1","tool_input":{}}'
expect_lacks "empty question allowed" "$OUT" "deny"
[[ $(jq '.decided|length' "$SD/a1.json") -ge 1 ]] && { pass=$((pass+1)); echo "ok   decisions recorded"; } || { fail=$((fail+1)); echo "FAIL decisions recorded"; }
[[ -f "$SD/a1.hud" ]] && { pass=$((pass+1)); echo "ok   hud line written"; } || { fail=$((fail+1)); echo "FAIL hud line written"; }
am --gate "$(Q a2 'Which colour scheme should the page use?')"
expect_lacks "other session unaffected" "$OUT" "deny"

# stop mode: each waits about a second for the reply to land, so run in parallel on separate sessions
for s in b1 b2 b3 b4; do am --on "$(S $s)"; done
am --on "$(S b5)" away
expect_has "away mode recorded" "$(cat "$SD/b5.json")" '"mode": "away"'
stop_rc() { printf '%s' "$(jq -nc --arg s "$1" --arg t "$2" '{session_id:$s,transcript_path:$t}')" \
  | env CLAUDE_CONFIG_DIR="$CFG" python3 "$H" --stop >/dev/null 2>"$TD/err-$1"; echo $? > "$TD/rc-$1"; }
T1=$(tr_for "I finished the first part. Next steps are open." b1)
T2=$(tr_for "All done.
STOPPED: need the API owner to confirm the contract" b2)
T3=$(tr_for "Report complete. Next I will deploy to production tonight." b3)
(stop_rc b1 "$T1"; cp "$TD/rc-b1" "$TD/rc-b1-first"; cp "$TD/err-b1" "$TD/err-b1-first"; stop_rc b1 "$T1") &
stop_rc b2 "$T2" &
stop_rc b3 "$T3" &
stop_rc b4 "$TD/nonexistent" &
wait
[[ "$(cat "$TD/rc-b1-first")" == 2 ]] && { pass=$((pass+1)); echo "ok   turn end pushes the model on"; } || { fail=$((fail+1)); echo "FAIL turn end pushes the model on"; }
expect_has "push carries the ladder" "$(cat "$TD/err-b1-first")" "Walk this ladder"
[[ "$(cat "$TD/rc-b1")" == 0 ]] && { pass=$((pass+1)); echo "ok   identical ending not pushed twice"; } || { fail=$((fail+1)); echo "FAIL identical ending not pushed twice"; }
[[ "$(cat "$TD/rc-b2")" == 0 ]] && { pass=$((pass+1)); echo "ok   STOPPED line honoured"; } || { fail=$((fail+1)); echo "FAIL STOPPED line honoured"; }
[[ "$(cat "$TD/rc-b3")" == 0 ]] && { pass=$((pass+1)); echo "ok   hard stop yields"; } || { fail=$((fail+1)); echo "FAIL hard stop yields"; }
[[ "$(cat "$TD/rc-b4")" == 0 ]] && { pass=$((pass+1)); echo "ok   unreadable transcript yields"; } || { fail=$((fail+1)); echo "FAIL unreadable transcript yields"; }

am --off "$(S a1)";                        expect_has "off confirms" "$OUT" "auto OFF"
[[ ! -f "$SD/a1.json" ]] && { pass=$((pass+1)); echo "ok   off clears state"; } || { fail=$((fail+1)); echo "FAIL off clears state"; }
jq '.since=1' "$SD/b5.json" > "$TD/x" && mv "$TD/x" "$SD/b5.json"
am --show "$(S b5)";                       expect_has "switch expires after a day" "$OUT" "auto is OFF"
finish
