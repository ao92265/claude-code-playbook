#!/bin/bash
# test-gate.py (Stop): a session that edited source and then ran nothing is blocked once (2); running code after the last edit passes.
source "$(dirname "$0")/lib.sh"
H=test-gate.py
export TEST_GATE_STATE="$TD/state" TEST_GATE_LOG="$TD/gate.log"
N=0
ts() { N=$((N+1)); printf '2026-01-01T00:%02d:%02dZ' $((N/60)) $((N%60)); }
# line <name> <input-json> [id]  -> one assistant tool_use transcript line
line() { jq -nc --arg t "$(ts)" --arg n "$1" --argjson i "$2" --arg id "${3:-id$N}" '{timestamp:$t,message:{content:[{type:"tool_use",name:$n,id:$id,input:$i}]}}'; }
edit() { line Edit "{\"file_path\":\"$1\"}" "${2:-}"; }
bash_() { line Bash "$(jq -nc --arg c "$1" '{command:$c}')"; }
failed() { jq -nc --arg id "$1" --arg t "$(ts)" '{timestamp:$t,message:{content:[{type:"tool_result",tool_use_id:$id,is_error:true}]}}'; }
# stop <session> [VAR=val ...]  (transcript built in $TD/t-<session>.jsonl by the caller)
stop() { local s="$1"; shift; run $H "$(jq -nc --arg s "$s" --arg t "$TD/t-$s.jsonl" '{session_id:$s,transcript_path:$t}')" "$@"; }

: > "$TD/t-none.jsonl"; bash_ "ls" >> "$TD/t-none.jsonl"
stop none;                                   expect "no source edits passes" 0

{ edit /w/src/a.ts; } > "$TD/t-bare.jsonl"
stop bare;                                   expect "edit with nothing run blocks" 2
expect_has "message says TEST GATE" "$ERR" "TEST GATE"
stop bare;                                   expect "second stop passes (blocks once)" 0

{ edit /w/src/a.ts; bash_ "npm test"; } > "$TD/t-ran.jsonl"
stop ran;                                    expect "test run after edit passes" 0
{ bash_ "npm test"; edit /w/src/a.ts; } > "$TD/t-before.jsonl"
stop before;                                 expect "test run before the last edit does not count" 2
{ edit /w/src/a.ts; bash_ "cat /w/src/a.ts"; } > "$TD/t-read.jsonl"
stop read;                                   expect "reading the file is not running it" 2
{ edit /w/src/a.py; bash_ "python3 /w/src/a.py"; } > "$TD/t-self.jsonl"
stop self;                                   expect "running the changed script passes" 0
{ edit /w/src/a.ts; bash_ "pip install pytest"; } > "$TD/t-pip.jsonl"
stop pip;                                    expect "installing a runner is not running" 2
{ edit /w/src/a.ts; bash_ "git commit -m 'fix; pytest passes'"; } > "$TD/t-msg.jsonl"
stop msg;                                    expect "runner named inside a commit message is not a run" 2
{ edit /w/src/a.ts; bash_ "curl -s http://localhost:3000/health"; } > "$TD/t-curl.jsonl"
stop curl;                                   expect "request to the local app counts" 0
{ edit /w/src/a.ts; bash_ "curl -s https://example.com"; } > "$TD/t-remote.jsonl"
stop remote;                                 expect "request to a remote host does not" 2
{ edit /w/src/a.ts; line Skill '{"skill":"done"}'; } > "$TD/t-skill.jsonl"
stop skill;                                  expect "done skill counts as a run" 0
{ edit /w/notes.md; } > "$TD/t-md.jsonl"
stop md;                                     expect "markdown edit is not source" 0
{ edit /w/src/a.ts e1; failed e1; } > "$TD/t-err.jsonl"
stop err;                                    expect "failed edit changed nothing" 0

{ edit /w/src/a.ts; } > "$TD/t-skip.jsonl"
stop skip CLAUDE_SKIP_HOOKS=test-gate;       expect "skip env honoured" 0
cp "$TD/t-skip.jsonl" "$TD/t-hdl.jsonl"
stop hdl CLAUDE_CODE_ENTRYPOINT=sdk-cli;     expect "headless entrypoint not gated" 0
run $H "$(jq -nc --arg t "$TD/t-bare.jsonl" '{session_id:"active",transcript_path:$t,stop_hook_active:true}')"; expect "stop_hook_active passes" 0
run $H 'not json';                           expect "bad json fails open" 0

# an edit made by a subagent counts, and so does a run it made after
mkdir -p "$TD/t-sub/subagents"; : > "$TD/t-sub.jsonl"
{ edit /w/src/sub.ts; } > "$TD/t-sub/subagents/a.jsonl"
stop sub;                                    expect "subagent edit is seen and blocks" 2
finish
