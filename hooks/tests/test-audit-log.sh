#!/bin/bash
# audit-log.sh: appends each prompt to a markdown audit file, never blocks.
source "$(dirname "$0")/lib.sh"
H=audit-log.sh
A="$TD/audit"
F="$A/prompts.md"

run $H '{"session_id":"s1","cwd":"/work/x","prompt":"first prompt"}' CLAUDE_AUDIT_DIR="$A"
expect "logs and exits 0" 0
[[ -f "$F" ]] && { pass=$((pass+1)); echo "ok   audit file created"; } || { fail=$((fail+1)); echo "FAIL audit file created"; }
LOG=$(cat "$F" 2>/dev/null)
expect_has "records prompt text" "$LOG" "first prompt"
expect_has "records session id" "$LOG" 's1'
expect_has "records cwd" "$LOG" "/work/x"
run $H '{"session_id":"s2","prompt":"second prompt"}' CLAUDE_AUDIT_DIR="$A"
LOG=$(cat "$F")
expect_has "appends, keeps first entry" "$LOG" "first prompt"
expect_has "appends second entry" "$LOG" "second prompt"
expect_has "missing cwd becomes unknown" "$LOG" 'unknown'
run $H '{}' CLAUDE_AUDIT_DIR="$A";             expect "empty payload exits 0" 0
n=$(grep -c '^## Prompt' "$F")
[[ "$n" == 3 ]] && { pass=$((pass+1)); echo "ok   three entries total"; } || { fail=$((fail+1)); echo "FAIL three entries total (got $n)"; }
finish
