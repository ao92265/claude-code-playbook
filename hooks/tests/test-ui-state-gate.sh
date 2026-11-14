#!/bin/bash
# ui-state-gate.sh blocks the first style edit of an armed visual-QA session (2), once;
# ui-state-recorder.sh stamps "asserted" only for a browser or theme-parity read that returned a resolved value.
source "$(dirname "$0")/lib.sh"
G=ui-state-gate.sh; REC=ui-state-recorder.sh
SD="$HOME/.claude/state/ui-state"; mkdir -p "$SD"
arm() { echo "parity check" > "$SD/armed-$1"; }
gate() { run $G "$(jq -nc --arg f "$1" --arg s "$2" '{session_id:$s,tool_input:{file_path:$f}}')" "${@:3}"; }
rec() { run $REC "$(jq -nc --arg t "$1" --arg c "$2" --arg o "$3" --arg s "$4" '{session_id:$s,tool_name:$t,tool_input:{code:$c,command:$c},tool_response:{stdout:$o}}')" "${@:5}"; }
Q="document.documentElement.getAttribute('data-theme')"

gate app.css s0;                      expect "unarmed session never blocked" 0
arm s1
gate app.css s1;                      expect "armed + css edit blocks" 2
expect_has "message says blocked" "$ERR" "BLOCKED"
gate app.css s1;                      expect "stands down after one block" 0
arm s2
gate app.test.tsx s2;                 expect "test file not gated" 0
gate notes.md s2;                     expect "markdown not gated" 0
gate server.py s2;                    expect "non-style file not gated" 0
gate Button.tsx s2;                   expect "tsx style-ish file blocks" 2
arm s3
gate app.css s3 CLAUDE_SKIP_HOOKS=ui-state; expect "skip env honoured" 0
run $G 'not json';                    expect "bad json ignored" 0

# recorder: a real read unlocks the gate without a block
arm s4
rec mcp__claude-in-chrome__javascript_tool "$Q" '"dark"' s4; expect "recorder exits 0" 0
gate app.css s4;                      expect "browser state read unlocks gate" 0
arm s5
rec Bash "grep -rn data-theme src/" 'theme=dark' s5
gate app.css s5;                      expect "plain grep does not satisfy gate" 2
arm s6
rec mcp__claude-in-chrome__javascript_tool "$Q" 'no idea' s6
gate app.css s6;                      expect "unresolved response does not satisfy gate" 2
arm s7
rec mcp__claude-in-chrome__javascript_tool "$Q" '' s7
gate app.css s7;                      expect "empty response does not satisfy gate" 2
arm s8
rec mcp__claude-in-chrome__javascript_tool "console.log(1)" 'true' s8
gate app.css s8;                      expect "non-state query does not satisfy gate" 2
arm s9
rec Bash "node theme-parity.js" 'theme=light' s9
gate app.css s9;                      expect "theme-parity tool satisfies gate" 0
arm s10
rec mcp__claude-in-chrome__javascript_tool "$Q" 'true' s10 CLAUDE_SKIP_HOOKS=ui-state
gate app.css s10;                     expect "recorder skip env records nothing" 2
finish
