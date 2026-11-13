#!/bin/bash
# pr-closing-keyword-guard.sh: closing verb + #N that the text contradicts is denied or asked.
source "$(dirname "$0")/lib.sh"
H=pr-closing-keyword-guard.sh
R="$TD/repo"; mkdir -p "$R"; cd "$R" || exit 1
git init -q . && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init
c() { jq -nc --arg c "$1" --arg cwd "$R" --arg t "${2:-Bash}" '{tool_name:$t,cwd:$cwd,tool_input:{command:$c}}'; }
decision() { [ -z "$OUT" ] && { echo none; return; }; jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$OUT"; }
chk() { if [[ "$(decision)" == "$2" ]]; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1 (got $(decision) want $2)"; fi; }

run $H "$(c 'gh pr create --title t --body "This does not close #12 but is related."')"; chk "negated close is denied" deny
run $H "$(c 'git commit -m "partially fixes #7"')";                                    chk "partially fixes is denied" deny
run $H "$(c 'gh pr create --title t --body "Refs #12. Still open."')";                  chk "Refs only is silent" none
run $H "$(c 'gh pr create --title t --body "Closes #12"')";                             chk "plain close is silent" none
run $H "$(c 'gh pr create --title t --body "Closes #12. #12 remains open for the follow-up."')"; chk "close plus remains asks" ask
run $H "$(c 'gh pr create --title t --body "Closes #12. Refs #12."')";                  chk "close plus Refs asks" ask
# An ack for this exact command (what pr-gate-ack-promote leaves after a human said yes) silences the repeat.
for p in $(find "$R" "$HOME" -name '*.pending' 2>/dev/null); do mv "$p" "${p%.pending}"; done
run $H "$(c 'gh pr create --title t --body "Closes #12. Refs #12."')";                  chk "acked repeat is silent" none
run $H "$(c 'gh pr edit 3 --body "Closes #4. Work on #4 is out of scope here."')";      chk "edit: deferral asks" ask
run $H "$(c 'ls -la')";                                                                 chk "unrelated command silent" none
run $H "$(c 'gh pr create --body "does not close #1"' Edit)";                           chk "non-Bash tool ignored" none
finish
