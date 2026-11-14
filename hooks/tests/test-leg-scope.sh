#!/bin/bash
# leg-scope.sh: --arm on continuation prompts, --record stamps "leg-done:", --gate blocks the first source edit once.
source "$(dirname "$0")/lib.sh"
mode() { local m="$1" in="$2"; shift 2; printf '%s' "$in" | env "$@" bash "$HOOKS_DIR/leg-scope.sh" "$m" >"$TD/out" 2>"$TD/err"; RC=$?; OUT=$(cat "$TD/out"); ERR=$(cat "$TD/err"); }
prompt() { jq -nc --arg s "$1" --arg p "$2" '{session_id:$s,prompt:$p}'; }
edit() { jq -nc --arg s "$1" --arg f "$2" '{session_id:$s,tool_input:{file_path:$f}}'; }
cmd() { jq -nc --arg s "$1" --arg c "$2" '{session_id:$s,tool_input:{command:$c}}'; }

mode --arm "$(prompt a1 "continue from where we left off yesterday")"; expect "arm exits 0" 0
expect_has "continuation prompt arms" "$OUT" "leg-scope"
mode --arm "$(prompt a2 "finish the login form validation")"; expect_lacks "ordinary ask does not arm" "$OUT" "leg-scope"
mode --arm "$(prompt a3 "please /reboot handoff pickup")";   expect_has "reboot opener arms" "$OUT" "leg-scope"
mode --arm "$(prompt a4 "hello")";                           expect_lacks "unrelated prompt does not arm" "$OUT" "leg-scope"

mode --gate "$(edit g0 /w/a.ts)";                            expect "unarmed edit allowed" 0
mode --arm "$(prompt g1 "resume from the handoff")"
mode --gate "$(edit g1 /w/notes.md)";                        expect "markdown not gated" 0
mode --gate "$(edit g1 /w/HANDOFF.sh)";                      expect "handoff file not gated" 0
mode --gate "$(edit g1 /w/a.xyz)";                           expect "unknown extension not gated" 0
mode --gate "$(edit g1 /w/a.ts)" CLAUDE_SKIP_HOOKS=leg-scope; expect "skip env honoured" 0
mode --gate "$(edit g1 /w/a.ts)";                            expect "armed first source edit blocks" 2
expect_has "message tells how to state it" "$ERR" "leg-done:"
mode --gate "$(edit g1 /w/b.ts)";                            expect "stands down after one block" 0

mode --arm "$(prompt r1 "carry on with the migration")"
mode --record "$(cmd r1 'echo "leg-done: push the branch and get review back green"')"; expect "record exits 0" 0
mode --gate "$(edit r1 /w/a.ts)";                            expect "stated finish line unblocks" 0
mode --arm "$(prompt r2 "carry on with the migration")"
mode --record "$(cmd r2 'echo "leg-done: ship it"')"
mode --gate "$(edit r2 /w/a.ts)";                            expect "trivially short finish line does not count" 2
mode --arm "$(prompt r3 "carry on with the migration")"
mode --record "$(cmd r3 'ls')"
mode --gate "$(edit r3 /w/a.ts)";                            expect "unrelated command does not count" 2
run leg-scope.sh 'not json';                                 expect "bad json ignored" 0
finish
