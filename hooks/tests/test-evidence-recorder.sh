#!/bin/bash
# evidence-recorder.sh: verification commands with output are appended to <repo>/.claude/evidence/runs.jsonl; nothing else is.
source "$(dirname "$0")/lib.sh"
H=evidence-recorder.sh
R="$TD/repo"; mkdir -p "$R"; git -C "$R" init -q -b main . ; git -C "$R" config user.email t@example.com; git -C "$R" config user.name t
echo a > "$R/a"; git -C "$R" add -A; git -C "$R" commit -qm init
L="$R/.claude/evidence/runs.jsonl"
rec() { run $H "$(jq -nc --arg c "$1" --arg d "$R" --argjson r "$2" '{tool_input:{command:$c},cwd:$d,tool_response:$r}')"; }
lines() { [ -f "$L" ] && wc -l < "$L" | tr -d ' ' || echo 0; }

rec "ls -la" '{"stdout":"file"}';            expect "non-verification exits 0" 0
[ "$(lines)" = 0 ]; expect_has "non-verification command not recorded" "$?" "0"
rec "npm test" '{"stdout":""}'
[ "$(lines)" = 0 ]; expect_has "empty output not recorded" "$?" "0"
rec "npm test" '{"stdout":"Tests: 12 passed"}'; expect "verification exits 0" 0
[ "$(lines)" = 1 ]; expect_has "verification run recorded" "$?" "0"
HEAD_SHA=$(git -C "$R" rev-parse HEAD)
expect_has "record carries the head sha" "$(jq -r .head "$L")" "$HEAD_SHA"
expect_has "record carries the output tail" "$(jq -r .tail "$L")" "12 passed"
expect_has "record carries the command" "$(jq -r .cmd "$L")" "npm test"
rec "pytest -q" '"4 passed in 0.1s"'
[ "$(lines)" = 2 ]; expect_has "bare string response recorded" "$?" "0"
rec "cd $R && go test ./..." '{"stdout":"ok pkg","stderr":""}'
[ "$(lines)" = 3 ]; expect_has "cd target resolves the repo" "$?" "0"
for i in 1 2 3; do rec "dotnet build" '{"stdout":"x"}'; done
[ "$(wc -l < "$L" | tr -d ' ')" = 6 ]; expect_has "each run is one json line" "$?" "0"
run $H 'not json';                           expect "bad json exits 0" 0
finish
