#!/usr/bin/env bash
# is_claude_cmd must match the claude program, not an argument that mentions it.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
eval "$(awk '/^is_claude_cmd\(\)/,/^}/' "$here/reap.sh")"
fail=0
chk() { printf '%s\n' "$2" | is_claude_cmd; got=$?; [ "$got" -eq "$1" ] || { echo "FAIL ($1 expected): $2"; fail=1; }; }
chk 0 "claude --resume abc"
chk 0 "/opt/homebrew/bin/claude"
chk 0 "node /x/node_modules/@anthropic-ai/claude-code/cli.js"
chk 1 "vim claude-notes.md"
chk 1 "less /tmp/claude.log"
chk 1 "-zsh"
[ $fail -eq 0 ] && echo "PASS"; exit $fail
