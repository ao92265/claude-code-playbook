#!/bin/bash
# pr-gate-ack-promote.sh: a pending ask marker becomes an approval only when the identical command ran.
source "$(dirname "$0")/lib.sh"
H=pr-gate-ack-promote.sh
A="$TD/acks"; mkdir -p "$A"
dig() { printf '%s' "$1" | cksum | cut -d' ' -f1; }
CMD="gh pr create --title t --body 'x'"
post() { run $H "$(jq -nc --arg t "${2:-Bash}" --arg c "$1" '{tool_name:$t,tool_input:{command:$c}}')" PR_GATE_ACK_DIR="$A"; }

dig "$CMD" > "$A/proj-branch-abc.pending"
post "gh pr create --title other --body 'y'"; expect "different command exits 0" 0
[ -e "$A/proj-branch-abc.pending" ] && [ ! -e "$A/proj-branch-abc" ]; expect_has "different command leaves marker pending" "$?" "0"
post "$CMD" Read
[ ! -e "$A/proj-branch-abc" ]; expect_has "non-Bash tool promotes nothing" "$?" "0"
post "$CMD"
[ -e "$A/proj-branch-abc" ] && [ ! -e "$A/proj-branch-abc.pending" ]; expect_has "identical command promotes to approval" "$?" "0"

dig "$CMD" > "$A/old-branch-def.pending"; touch -t 202001010000 "$A/old-branch-def.pending"
post "unrelated";
[ ! -e "$A/old-branch-def.pending" ] && [ ! -e "$A/old-branch-def" ]; expect_has "stale pending is removed, not promoted" "$?" "0"
run $H '{"tool_name":"Bash","tool_input":{}}' PR_GATE_ACK_DIR="$A"; expect "empty command ok" 0
run $H "$(bash_payload x)" PR_GATE_ACK_DIR="$TD/missing"; expect "missing ack dir ok" 0
finish
