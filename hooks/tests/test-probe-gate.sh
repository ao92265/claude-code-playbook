#!/bin/bash
# probe-gate.sh blocks code that reaches an unprobed service (2, once per service);
# probe-recorder.sh stamps a probe only when a command named the host AND returned output.
source "$(dirname "$0")/lib.sh"
G=probe-gate.sh; REC=probe-recorder.sh
gate() { run $G "$(jq -nc --arg f "$1" --arg c "$2" --arg s "${3:-s1}" '{session_id:$s,tool_input:{file_path:$f,content:$c}}')" "${@:4}"; }
rec()  { run $REC "$(jq -nc --arg c "$1" --arg o "$2" --arg s "${3:-s1}" '{session_id:$s,tool_input:{command:$c},tool_response:{stdout:$o}}')" "${@:4}"; }
GRAPH='fetch("https://graph.microsoft.com/v1.0/me")'

gate app.ts "$GRAPH";                 expect "unprobed service blocks" 2
expect_has "names the service" "$ERR" "outlook"
gate app.ts "$GRAPH";                 expect "second try goes through (waived once)" 0
gate app.ts "$GRAPH" s2;              expect "other session still blocked" 2
gate app.md "$GRAPH" s3;              expect "markdown skipped" 0
gate app.test.ts "$GRAPH" s3;         expect "test file skipped" 0
gate app.ts 'const x = "hello world"' s3; expect "no service reach passes" 0
gate app.ts 'see outlook docs' s3;    expect "bare mention not a reach" 0
gate app.ts "$GRAPH" s3 CLAUDE_SKIP_HOOKS=probe; expect "skip env honoured" 0
gate app.py 'url="https://api.figma.com/v1/me"; x="https://api.linkedin.com/v2/me"' s4; expect "multi service blocks" 2
expect_has "reports both services once" "$ERR" "linkedin figma"

# recorder: a real probe with output unlocks the gate
rec 'curl https://graph.microsoft.com/v1.0/me' '{"error":"401"}' s5; expect "recorder exits 0" 0
gate app.ts "$GRAPH" s5;              expect "recorded probe unlocks gate" 0
rec 'curl https://api.figma.com/v1/me' '' s6
gate app.ts 'fetch("https://api.figma.com/v1/me")' s6; expect "probe with empty response does not unlock" 2
rec 'echo probe-ok:figma' '' s7
gate app.ts 'fetch("https://api.figma.com/v1/me")' s7; expect "manual probe-ok stamp unlocks" 0
rec 'curl https://api.figma.com/v1/me' 'ok' s8
gate app.ts "$GRAPH" s8;              expect "probe of one service does not unlock another" 2
rec 'curl https://graph.microsoft.com/v1.0/me' 'ok' s9 CLAUDE_SKIP_HOOKS=probe
gate app.ts "$GRAPH" s9;              expect "recorder skip env writes nothing" 2
run $REC 'not json';                  expect "recorder ignores bad json" 0
run $G 'not json';                    expect "gate ignores bad json" 0
finish
