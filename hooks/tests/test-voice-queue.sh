#!/bin/bash
# voice-queue.sh: records which sessions are waiting on the user (finished, permission, menu, waiting) and clears on prompt.
source "$(dirname "$0")/lib.sh"
H=voice-queue.sh
Q="$TD/q"
# run passes extra args to env, so the event goes through bash: call the script with the event as its argument
vq() { printf '%s' "$2" | env VOICE_QUEUE_DIR="$Q" "${@:3}" bash "$HOOKS_DIR/$H" "$1" >"$TD/out" 2>"$TD/err"; RC=$?; }
f() { jq -r "$1" "$Q/s1.json" 2>/dev/null; }
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }

vq stop '{"session_id":"s1","cwd":"/work/myproj","last_assistant_message":"All done here"}'; expect "stop exits 0" 0
check "stop records finished" '[[ "$(f .kind)" == finished ]]'
check "stop records project from cwd" '[[ "$(f .project)" == myproj ]]'
check "stop records reply text" '[[ "$(f .text)" == "All done here" ]]'
LONG=$(printf 'x%.0s' $(seq 1 600))END
vq stop "$(jq -nc --arg m "$LONG" '{session_id:"s1",cwd:"/w/p",last_assistant_message:$m}')"
check "text keeps only the last 400 chars" '[[ "$(f ".text|length")" == 400 && "$(f .text)" == *END ]]'
vq notification '{"session_id":"s1","cwd":"/w/p","message":"Claude needs your permission to use Bash"}'
check "permission notification" '[[ "$(f .kind)" == permission ]]'
vq notification '{"session_id":"s1","cwd":"/w/p","message":"Plan ready for approval"}'
check "approval notification is a menu" '[[ "$(f .kind)" == menu ]]'
vq notification '{"session_id":"s1","cwd":"/w/p","message":"Claude is waiting for your input"}'
check "idle ping keeps an existing entry" '[[ "$(f .kind)" == menu ]]'
vq prompt '{"session_id":"s1"}'
check "prompt clears the entry" '[[ ! -e "$Q/s1.json" ]]'
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"What should I name it?"}]}}' > "$TD/t.jsonl"
vq notification "$(jq -nc --arg t "$TD/t.jsonl" '{session_id:"s1",cwd:"/w/p",message:"Claude is waiting for your input",transcript_path:$t}')"
check "idle ping with no entry reads last reply" '[[ "$(f .kind)" == waiting && "$(f .text)" == "What should I name it?" ]]'
vq stop '{"cwd":"/w/p","last_assistant_message":"x"}'; expect "no session id exits 0" 0
check "no session id records nothing" '[[ $(ls "$Q" | wc -l) -eq 1 ]]'
vq prompt '{"session_id":"s1"}'
vq stop '{"session_id":"s1","last_assistant_message":"x"}' CLAUDE_SKIP_HOOKS=voice-queue
check "skip env records nothing" '[[ ! -e "$Q/s1.json" ]]'
finish
