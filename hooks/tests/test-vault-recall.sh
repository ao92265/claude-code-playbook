#!/bin/bash
# vault-recall.py: surfaces vault notes whose titles match prompt keywords; silent otherwise.
source "$(dirname "$0")/lib.sh"
H=vault-recall.py
mkdir -p "$HOME/.claude/vault-index"
printf 'Projects/zebrafinch.md\tZebrafinch migration plan\talpha\nArea/Archive/old.md\tZebrafinch ancient notes\t\nNotes/other.md\tUnrelated gardening topic\t\n' > "$HOME/.claude/vault-index/titles.tsv"
p() { jq -nc --arg p "$1" '{prompt:$p}'; }

run $H "$(p 'what is the zebrafinch migration status')"; expect "match exits 0" 0
expect_has "surfaces the matching note" "$OUT" "zebrafinch.md"
expect_has "output is hook JSON" "$OUT" "additionalContext"
expect_lacks "unrelated note excluded" "$OUT" "gardening"
expect_lacks "archive path excluded" "$OUT" "old.md"
run $H "$(p 'tell me about the cooking recipes please')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   no match silent"; } || { fail=$((fail+1)); echo "FAIL no match silent"; }
run $H "$(p 'zebrafinch')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   short prompt silent"; } || { fail=$((fail+1)); echo "FAIL short prompt silent"; }
run $H "$(p '/zebrafinch migration plan status now')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   slash command silent"; } || { fail=$((fail+1)); echo "FAIL slash command silent"; }
run $H "$(p '<task-notification>zebrafinch migration plan</task-notification>')"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   system block silent"; } || { fail=$((fail+1)); echo "FAIL system block silent"; }
run $H 'garbage';                         expect "bad input exits 0" 0
finish
