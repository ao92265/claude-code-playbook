#!/bin/bash
# Tiny shared harness for the hook tests. Source it, call check/expect, end with finish.
# Hooks run against the repo copy (HOOKS_DIR), never ~/.claude, with HOME pointed at a temp dir.
HOOKS_DIR=${HOOKS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
TD=$(mktemp -d)
trap 'rm -rf "$TD"' EXIT
export HOME="$TD/home"; mkdir -p "$HOME"
unset CLAUDE_SKIP_HOOKS OMC_SKIP_HOOKS CLAUDE_PROJECT_DIR
pass=0; fail=0
ERR=""; OUT=""

# run <hook-file> <stdin> [VAR=val ...]  -> sets RC, OUT (stdout), ERR (stderr)
run() {
  local hook="$1" input="$2"; shift 2
  local interp=bash; [[ "$hook" == *.py ]] && interp=python3
  printf '%s' "$input" | env "$@" "$interp" "$HOOKS_DIR/$hook" >"$TD/out" 2>"$TD/err"
  RC=$?; OUT=$(cat "$TD/out"); ERR=$(cat "$TD/err")
}

# expect <name> <want-rc>   (uses RC from the last run)
expect() {
  if [[ "$RC" == "$2" ]]; then pass=$((pass+1)); printf 'ok   %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL %s (exit=%s want=%s)\n' "$1" "$RC" "$2"; fi
}

# expect_has <name> <haystack> <needle>
expect_has() {
  if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); printf 'ok   %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL %s (missing: %s)\n' "$1" "$3"; fi
}

# expect_lacks <name> <haystack> <needle>
expect_lacks() {
  if [[ "$2" != *"$3"* ]]; then pass=$((pass+1)); printf 'ok   %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL %s (unexpected: %s)\n' "$1" "$3"; fi
}

# bash_payload <command>  -> PreToolUse Bash JSON
bash_payload() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
# file_payload <tool> <path> [content]
file_payload() { jq -nc --arg t "$1" --arg f "$2" --arg c "${3:-}" '{tool_name:$t,tool_input:{file_path:$f,content:$c,new_string:$c}}'; }

finish() { echo "passed $pass, failed $fail"; [[ $fail == 0 ]]; }
