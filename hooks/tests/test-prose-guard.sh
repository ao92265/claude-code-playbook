#!/bin/bash
# prose-guard.sh: em/en dashes in prose written by Edit/Write exit 2.
source "$(dirname "$0")/lib.sh"
H=prose-guard.sh
EM=$'\xe2\x80\x94'; EN=$'\xe2\x80\x93'
try() { run $H "$(file_payload "$2" "$3" "$4")"; expect "$1" "$5"; }

try "em dash in md blocked"   Write /p/a.md   "one ${EM} two" 2
try "en dash in txt blocked"  Write /p/a.txt  "1${EN}2" 2
try "em dash in .markdown"    Write /p/a.markdown "x ${EM} y" 2
try "plain text in md ok"     Write /p/a.md   "one, two" 0
try "em dash in code ok"      Write /p/a.py   "# one ${EM} two" 0
try "hyphen in md ok"         Write /p/a.md   "well-known" 0
try "own hooks dir exempt"    Write "$HOME/.claude/hooks/x.md" "a ${EM} b" 0
run $H "$(jq -nc --arg f /p/a.md --arg s "x ${EM} y" '{tool_input:{file_path:$f,edits:[{new_string:$s}]}}')"
expect "multi-edit new_string blocked" 2
run $H "$(jq -nc --arg f /p/a.md --arg s "x ${EM} y" '{tool_input:{file_path:$f,old_string:$s,new_string:"x, y"}}')"
expect "dash only in old_string ok" 0
run $H "$(file_payload Write /p/a.md "a ${EM} b")" CLAUDE_SKIP_HOOKS=prose-guard; expect "skip env honoured" 0
finish
