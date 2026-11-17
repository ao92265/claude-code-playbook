#!/usr/bin/env bash
# status-shape-gate must read the last real user prompt (not a tool-result
# record) and must not fire on ordinary tasks that merely mention "status".
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/status-shape-gate.sh"
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
long=$(printf 'word %.0s' $(seq 1 100))
run() { # $1 = user prompt json content
  { printf '{"type":"user","message":{"content":%s}}\n' "$1"
    printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"X"}]}}\n'
    printf '{"type":"user","message":{"content":[{"type":"tool_result","content":"ok"}]}}\n'
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"%s"}]}}\n' "$long"
  } > "$d/t.jsonl"
  printf '{"transcript_path":"%s"}' "$d/t.jsonl" | bash "$hook" 2>/dev/null; echo $?
}
fail=0
exp() { [ "$2" = "$1" ] || { echo "FAIL: $3 (want $1 got $2)"; fail=1; }; }
exp 2 "$(run '"where are we"')" "string prompt behind tool_result blocks"
exp 2 "$(run '[{"type":"text","text":"keep going"}]')" "array prompt behind tool_result"
exp 0 "$(run '"fix the status code in the API"')" "task mentioning status"
[ $fail -eq 0 ] && echo PASS; exit $fail
