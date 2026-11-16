#!/bin/bash
# goal-pin.py: first real prompt becomes the goal, echo markers move it, detours push and pop, stop blocks once per plan change.
source "$(dirname "$0")/lib.sh"
H="$HOOKS_DIR/goal-pin.py"
CFG="$HOME/.claude"
SD="$CFG/state/goal-pin"
gp() { # <mode> <stdin-json> [VAR=val ...]
  local m="$1" in="$2"; shift 2
  printf '%s' "$in" | env CLAUDE_CONFIG_DIR="$CFG" "$@" python3 "$H" "$m" >"$TD/o" 2>"$TD/e"
  RC=$?; OUT=$(cat "$TD/o"); ERR=$(cat "$TD/e")
}
P() { jq -nc --arg p "$1" --arg s "${2:-g1}" '{prompt:$p,session_id:$s}'; }
B() { jq -nc --arg c "$1" --arg s "${2:-g1}" '{tool_input:{command:$c},session_id:$s}'; }
field() { jq -r "$2" "$SD/$1.json" 2>/dev/null; }

gp --prompt "$(P 'Please migrate the billing module to the new client')"
expect "prompt exits 0" 0
expect_has "reminder carries the goal" "$OUT" "session goal = Please migrate the billing"
[[ "$(field g1 .source)" == auto ]] && { pass=$((pass+1)); echo "ok   first prompt is the auto goal"; } || { fail=$((fail+1)); echo "FAIL first prompt is the auto goal"; }
[[ -f "$SD/g1.hud" ]] && { pass=$((pass+1)); echo "ok   hud line written"; } || { fail=$((fail+1)); echo "FAIL hud line written"; }
gp --prompt "$(P 'a different second prompt about something else' g1)"
[[ "$(field g1 .goal)" == Please* ]] && { pass=$((pass+1)); echo "ok   second prompt keeps goal"; } || { fail=$((fail+1)); echo "FAIL second prompt keeps goal"; }
gp --prompt "$(P 'ok' g2)"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   trivial prompt sets no goal"; } || { fail=$((fail+1)); echo "FAIL trivial prompt sets no goal"; }

gp --record "$(B 'echo "goal: ship the report"')"
[[ "$(field g1 .goal)" == "ship the report" && "$(field g1 .source)" == stated ]] && { pass=$((pass+1)); echo "ok   stated goal beats auto"; } || { fail=$((fail+1)); echo "FAIL stated goal beats auto"; }
gp --record "$(B 'echo "asked-for: something weaker"')"
[[ "$(field g1 .goal)" == "ship the report" ]] && { pass=$((pass+1)); echo "ok   asked-for does not beat stated"; } || { fail=$((fail+1)); echo "FAIL asked-for does not beat stated"; }
gp --record "$(B 'echo "detour: fix flaky test"')"
[[ "$(field g1 '.detours|length')" == 1 ]] && { pass=$((pass+1)); echo "ok   detour pushed"; } || { fail=$((fail+1)); echo "FAIL detour pushed"; }
gp --record "$(B 'cat <<EOF
goal: in a heredoc
EOF')"
[[ "$(field g1 .goal)" == "ship the report" ]] && { pass=$((pass+1)); echo "ok   heredoc text is not a marker"; } || { fail=$((fail+1)); echo "FAIL heredoc text is not a marker"; }
gp --prompt "$(P 'and now continue with the next thing' g1)"
expect_has "side-track shown in reminder" "$OUT" "Current side-track: fix flaky test"
gp --record "$(B 'echo detour-done')"
[[ "$(field g1 '.detours|length')" == 0 ]] && { pass=$((pass+1)); echo "ok   detour popped"; } || { fail=$((fail+1)); echo "FAIL detour popped"; }

# idle gap produces a recap request
jq '.last_seen=1' "$SD/g1.json" > "$SD/x" && mv "$SD/x" "$SD/g1.json"
gp --prompt "$(P 'back again after a long break here' g1)"
expect_has "idle gap asks for a recap" "$OUT" "has been away"

# stop gate: blocks once per plan revision
gp --stop "$(jq -nc '{session_id:"g1"}')";       expect "unposted plan blocks stop" 2
expect_has "stop names the board" "$ERR" "session board"
gp --stop "$(jq -nc '{session_id:"g1"}')";       expect "same revision not blocked twice" 0
gp --record "$(B 'echo "goal: a newer goal"')"
gp --stop "$(jq -nc '{session_id:"g1",stop_hook_active:true}')"; expect "stop continuation passes" 0
gp --stop "$(jq -nc '{session_id:"g1"}')";       expect "changed plan blocks again" 2
gp --posted "$(jq -nc '{session_id:"g1",tool_input:{collection:"sessions",doc_id:"g1",data:{state:"live"}}}')"
gp --record "$(B 'echo "detour: later"')"; gp --posted "$(jq -nc '{session_id:"g1",tool_input:{collection:"sessions",doc_id:"g1"}}')"
gp --stop "$(jq -nc '{session_id:"g1"}')";       expect "posted strip passes stop" 0

gp --session "$(jq -nc '{session_id:"g1",source:"resume"}')"
expect_has "resume prints recap" "$OUT" "Goal:"
gp --session "$(jq -nc '{session_id:"g1",source:"startup"}')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   startup prints nothing"; } || { fail=$((fail+1)); echo "FAIL startup prints nothing"; }
gp --prompt "$(P 'Please migrate the billing module to the new client' g3)" CLAUDE_SKIP_HOOKS=goal-pin
[[ ! -f "$SD/g3.json" ]] && { pass=$((pass+1)); echo "ok   skip env writes nothing"; } || { fail=$((fail+1)); echo "FAIL skip env writes nothing"; }
finish
