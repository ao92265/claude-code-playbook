#!/bin/bash
# require-agent-model.sh: Agent/Task calls need an explicit model unless the definition pins one.
source "$(dirname "$0")/lib.sh"
H=require-agent-model.sh
cd "$TD" || exit 1
ag() { jq -nc --arg t "$1" --arg m "$2" --arg s "$3" --arg sid "${4:-s1}" \
  '{tool_name:$t,session_id:$sid,tool_input:({subagent_type:$s}+(if $m=="" then {} else {model:$m} end))}'; }

run $H "$(ag Agent "" general-purpose)";   expect "Agent no model blocked" 2
run $H "$(ag Task "" general-purpose)";    expect "Task no model blocked" 2
run $H "$(ag Agent haiku general-purpose)"; expect "Agent with model ok" 0
run $H "$(jq -nc '{tool_name:"Bash",tool_input:{command:"ls"}}')"; expect "non-Agent tool ok" 0
run $H "$(ag Agent opus Explore)";         expect "opus on Explore blocked" 2
run $H "$(ag Agent opus architect)";       expect "opus on architect ok" 0
run $H "$(ag Agent opus Explore)" OPUS_OK=1; expect "OPUS_OK allows opus Explore" 0
run $H "$(ag Agent "" general-purpose)" CLAUDE_CODE_SUBAGENT_MODEL=haiku; expect "subagent model env allows" 0
run $H "$(ag Agent "" general-purpose)" REQUIRE_AGENT_MODEL_DISABLED=1;   expect "disable env allows" 0

mkdir -p "$TD/.claude/agents"
printf -- '---\nname: pinned\nmodel: sonnet\n---\nbody\n' > "$TD/.claude/agents/pinned.md"
printf -- '---\nname: loose\n---\nbody\n' > "$TD/.claude/agents/loose.md"
run $H "$(ag Agent "" pinned)";            expect "pinned definition passes" 0
run $H "$(ag Agent "" loose)";             expect "definition without model blocked" 2

# Tripwire: the 3rd opus call with limit 2 is blocked.
for i in 1 2; do run $H "$(ag Agent opus architect trip)" OPUS_SESSION_LIMIT=2; done
expect "opus under limit ok" 0
run $H "$(ag Agent opus architect trip)" OPUS_SESSION_LIMIT=2; expect "opus over limit blocked" 2
finish
