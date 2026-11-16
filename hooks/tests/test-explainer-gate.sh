#!/bin/bash
# explainer-gate.py: first edit to an existing source file in a folder is blocked until an "Explainer:" line is written; gives up after two blocks.
source "$(dirname "$0")/lib.sh"
# Work files live under /var/tmp: the hook treats /tmp and /var/folders (where mktemp lands) as scratch.
W=$(mktemp -d /var/tmp/hooktest.XXXXXX)
trap 'rm -r "$W" "$TD" 2>/dev/null' EXIT
H=explainer-gate.py
export EXPLAINER_STATE="$TD/state"
mkdir -p "$W/src" "$W/lib"; echo x > "$W/src/a.ts"; echo x > "$W/src/b.ts"; echo x > "$W/lib/c.ts"; echo x > "$W/src/n.md"
TR="$W/tr.jsonl"; : > "$TR"
ed() { run $H "$(jq -nc --arg s "$1" --arg f "$2" --arg t "$TR" '{session_id:$s,transcript_path:$t,tool_input:{file_path:$f}}')" "${@:3}"; }
say() { jq -nc --arg x "$1" '{type:"assistant",message:{content:[{type:"text",text:$x}]}}' >> "$TR"; }
LONG="Explainer: this folder holds the widgets; the edit changes how a widget is built and callers rely on it staying stable."

ed s1 "$W/src/a.ts";                        expect "first edit in a folder blocks" 2
expect_has "asks for an Explainer line" "$ERR" "Explainer:"
ed s1 "$W/src/b.ts";                        expect "retry without explainer blocks again" 2
ed s1 "$W/src/a.ts";                        expect "gives up after two blocks, never traps" 0
ed s1 "$W/src/b.ts";                        expect "stays allowed once given up" 0

ed s2 "$W/src/a.ts"
say "Explainer: gate fired"
ed s2 "$W/src/a.ts";                        expect "short narration does not satisfy the gate" 2
say "$LONG"
ed s2 "$W/src/a.ts";                        expect "real explainer after the block unblocks" 0
ed s2 "$W/lib/c.ts";                        expect "a different folder is gated separately" 2

ed s3 "$W/src/new-file.ts";                 expect "new file not gated" 0
ed s3 "$W/src/n.md";                        expect "markdown not gated" 0
ed s3 "$W/src/a.ts" CLAUDE_SKIP_HOOKS=explainer-gate; expect "skip env honoured" 0
run $H "$(jq -nc --arg f "$W/src/a.ts" '{session_id:"s4",agent_id:"sub",tool_input:{file_path:$f}}')"; expect "subagent not gated" 0
run $H "$(jq -nc --arg f "$W/src/a.ts" '{tool_input:{file_path:$f}}')"; expect "no session id not gated" 0
run $H 'not json';                           expect "bad json fails open" 0
finish
