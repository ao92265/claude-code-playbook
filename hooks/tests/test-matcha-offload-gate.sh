#!/bin/bash
# matcha-offload-gate.sh: when the usage window is nearly spent, cheap-tier subagent spawns are blocked (2).
source "$(dirname "$0")/lib.sh"
command -v zsh >/dev/null || { echo "skip: no zsh"; exit 0; }
# The hook is a zsh script, so run it with zsh like its shebang does.
gate() { printf '%s' "$1" | env "${@:2}" zsh "$HOOKS_DIR/matcha-offload-gate.sh" >"$TD/out" 2>"$TD/err"; RC=$?; ERR=$(cat "$TD/err"); }
agent() { jq -nc --arg m "$1" '{tool_name:"Agent",tool_input:{model:$m,prompt:"x"}}'; }
usage() { mkdir -p "$HOME/.claude"; printf '{"five_hour":{"used_percentage":%s},"seven_day":{"used_percentage":%s}}\n' "$1" "$2" > "$HOME/.claude/usage-history.jsonl"; }

gate "$(agent haiku)";                       expect "no usage file allows" 0
usage 10 10
gate "$(agent haiku)";                       expect "plenty of headroom allows" 0
usage 95 10
gate "$(agent haiku)";                       expect "five hour window nearly spent blocks haiku" 2
expect_has "message shows the percentage" "$ERR" "95%"
gate "$(agent sonnet)";                      expect "five hour window blocks sonnet too" 2
gate "$(agent opus)";                        expect "top tier still runs" 0
gate "$(agent '')";                          expect "no model still runs" 0
gate "$(agent haiku)" MATCHA_OFFLOAD_OK=1;   expect "explicit bypass honoured" 0
gate "$(agent haiku)" CLAUDE_SKIP_HOOKS=matcha; expect "skip env honoured" 0
usage 10 93
gate "$(agent haiku)";                       expect "weekly window nearly spent blocks" 2
usage 89 91
gate "$(agent haiku)";                       expect "just under both thresholds allows" 0
usage 95 95; touch -t 202001010000 "$HOME/.claude/usage-history.jsonl"
gate "$(agent haiku)";                       expect "stale usage data fails open" 0
gate "";                                     expect "empty payload allows" 0
finish
