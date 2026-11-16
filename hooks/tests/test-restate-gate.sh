#!/bin/bash
# restate-gate.sh: --arm on the first real ask, --record stamps "asked-for:", --gate blocks the first source edit once.
source "$(dirname "$0")/lib.sh"
export RESTATE_GATE_STATE="$TD/rg"
# mode <--arm|--record|--gate> <json> [VAR=val ...]
mode() { local m="$1" in="$2"; shift 2; printf '%s' "$in" | env "$@" bash "$HOOKS_DIR/restate-gate.sh" "$m" >"$TD/out" 2>"$TD/err"; RC=$?; OUT=$(cat "$TD/out"); ERR=$(cat "$TD/err"); }
prompt() { jq -nc --arg s "$1" --arg p "$2" '{session_id:$s,prompt:$p}'; }
edit() { jq -nc --arg s "$1" --arg f "$2" '{session_id:$s,tool_input:{file_path:$f}}'; }
cmd() { jq -nc --arg s "$1" --arg c "$2" '{session_id:$s,tool_input:{command:$c}}'; }
ASK="please rename the widget factory across the whole service"

mode --arm "$(prompt a1 "$ASK")";            expect "arm exits 0" 0
expect_has "arm injects reminder" "$OUT" "restate-gate"
mode --arm "$(prompt a1 "$ASK again please now")"; expect_lacks "second ask does not re-arm" "$OUT" "restate-gate"
mode --arm "$(prompt a2 "fix it")";          expect_lacks "short prompt does not arm" "$OUT" "restate-gate"
mode --arm "$(prompt a3 "/loop do the thing every five minutes please")"; expect_lacks "slash command does not arm" "$OUT" "restate-gate"
mode --arm "$(prompt a4 "continue from where we left off yesterday please")"; expect_lacks "continuation skipped" "$OUT" "restate-gate"
mode --arm "$(prompt a5 "$ASK")" CLAUDE_CODE_ENTRYPOINT=sdk-cli; expect_lacks "headless never arms" "$OUT" "restate-gate"

# gate
mode --gate "$(edit g0 /w/a.ts)";            expect "unarmed edit allowed" 0
mode --arm "$(prompt g0 "$ASK")";            expect_lacks "edit before ask stops later arming" "$OUT" "restate-gate"
mode --arm "$(prompt g1 "$ASK")"
mode --gate "$(edit g1 /w/notes.md)";        expect "markdown edit not gated" 0
mode --gate "$(edit g1 /w/data.xyz)";        expect "unknown extension not gated" 0
mode --gate "$(jq -nc '{session_id:"g1",agent_id:"sub",tool_input:{file_path:"/w/a.ts"}}')"; expect "subagent not gated" 0
mode --gate "$(edit g1 /w/a.ts)" CLAUDE_SKIP_HOOKS=restate-gate; expect "skip env honoured" 0
mode --gate "$(edit g1 /w/a.ts)";            expect "first source edit blocks" 2
expect_has "block shows the ask" "$ERR" "rename the widget"
mode --gate "$(edit g1 /w/b.ts)";            expect "stands down after one block" 0

# record, then gate passes without blocking
mode --arm "$(prompt r1 "$ASK")"
mode --record "$(cmd r1 'echo "asked-for: rename widget factory everywhere"')"; expect "record exits 0" 0
mode --gate "$(edit r1 /w/a.ts)";            expect "restated session edits freely" 0
mode --arm "$(prompt r2 "$ASK")"
mode --record "$(cmd r2 'echo "asked-for: too short"')"
mode --gate "$(edit r2 /w/a.ts)";            expect "too-short restatement does not count" 2
mode --arm "$(prompt r3 "$ASK")"
mode --record "$(cmd r3 'ls -la')"
mode --gate "$(edit r3 /w/a.ts)";            expect "unrelated command does not count" 2
mode --arm "$(prompt r4 "$ASK")"
mode --record "$(cmd r4 "echo \"asked-for: don't rename it, rename everything\" && git status")"
mode --gate "$(edit r4 /w/a.ts)";            expect "apostrophe and shell tail still record" 0
finish
