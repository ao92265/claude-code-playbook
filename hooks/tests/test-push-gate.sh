#!/bin/bash
# push-gate.py (Stop): a session that ran `git commit` and left the commits unpushed is nudged once (2); allow list, no remote, headless and repeat stops pass.
source "$(dirname "$0")/lib.sh"
H=push-gate.py
export PUSH_GATE_STATE="$TD/state" PUSH_GATE_ALLOW="$TD/allow"
git config --global user.email t@example.com 2>/dev/null; git config --global user.name t 2>/dev/null   # HOME is the temp dir
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
git init -q --bare "$TD/origin.git"
git clone -q "$TD/origin.git" "$TD/work" 2>/dev/null; cd "$TD/work" || exit 1
git checkout -q -b feat; echo a > a; git add -A; git commit -qm base; git push -q -u origin feat 2>/dev/null
SINCE=$(t=$(( $(date +%s) - 3600 )); date -u -d "@$t" +%FT%TZ 2>/dev/null || date -u -r "$t" +%FT%TZ)
# tr <name> <entrypoint> <command...>  -> transcript with one Bash tool_use per command
mk_tr() { local f="$TD/t-$1.jsonl"; : > "$f"; local ep="$2"; shift 2; local c
  for c in "$@"; do jq -nc --arg ts "$SINCE" --arg ep "$ep" --arg cwd "$TD/work" --arg c "$c" \
    '{timestamp:$ts,entrypoint:$ep,cwd:$cwd,message:{content:[{type:"tool_use",name:"Bash",input:{command:$c}}]}}' >> "$f"; done; }
stop() { run $H "$(jq -nc --arg s "$1" --arg t "$TD/t-$1.jsonl" --arg c "$TD/work" '{session_id:$s,transcript_path:$t,cwd:$c}')" "${@:2}"; }

mk_tr clean cli "git commit -m x"
stop clean;                                  expect "commit already pushed passes" 0
echo b > b; git add -A; git commit -qm second
mk_tr nocommit cli "ls"
stop nocommit;                               expect "no commit command in session passes" 0
mk_tr dirty cli "git commit -m second"
stop dirty;                                  expect "unpushed commit blocks" 2
expect_has "nudge says what to do" "$ERR" "did not push"
stop dirty;                                  expect "same state is only nudged once" 0
mk_tr act cli "git commit -m second"
run $H "$(jq -nc --arg t "$TD/t-act.jsonl" --arg c "$TD/work" '{session_id:"act",transcript_path:$t,cwd:$c,stop_hook_active:true}')"; expect "stop_hook_active passes" 0
mk_tr hdl sdk-cli "git commit -m second"
stop hdl;                                    expect "headless run not nudged" 0
mk_tr skp cli "git commit -m second"
stop skp CLAUDE_SKIP_HOOKS=push-gate;        expect "skip env honoured" 0
echo work > "$TD/allow"
mk_tr alw cli "git commit -m second"
stop alw;                                    expect "allow-listed repo passes" 0
: > "$TD/allow"
mk_tr q cli "echo 'git commit later'"
stop q;                                      expect "quoted mention is not a commit" 0
git push -q origin feat 2>/dev/null
mk_tr pushed cli "git commit -m second" "git push"
stop pushed;                                 expect "pushed commits pass" 0

# repo with no remote
git init -q "$TD/local" ; cd "$TD/local" || exit 1; echo a > a; git add -A; git commit -qm one
jq -nc --arg ts "$SINCE" --arg cwd "$TD/local" '{timestamp:$ts,entrypoint:"cli",cwd:$cwd,message:{content:[{type:"tool_use",name:"Bash",input:{command:"git commit -m one"}}]}}' > "$TD/t-local.jsonl"
run $H "$(jq -nc --arg t "$TD/t-local.jsonl" --arg c "$TD/local" '{session_id:"local",transcript_path:$t,cwd:$c}')"; expect "repo with no remote passes" 0
run $H 'not json';                           expect "bad json fails open" 0
finish
