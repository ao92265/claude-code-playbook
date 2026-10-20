#!/bin/bash
# restate-gate.sh: a fresh session must say back what it was asked before its
# first source edit. Continuation sessions are left to leg-scope.
HOOK="$HOME/.claude/hooks/restate-gate.sh"
FAIL=0
T=$(mktemp -d)
ok() { [ "$1" -eq "$2" ] && echo "OK   $3" || { echo "FAIL $3 (want $1 got $2)"; FAIL=$((FAIL+1)); }; }
call() { # mode, json, [entrypoint]; prints stdout to $T/out, stderr to $T/err
  printf '%s' "$2" | env -u CLAUDE_SKIP_HOOKS -u OMC_SKIP_HOOKS RESTATE_GATE_STATE="$T/state" CLAUDE_CODE_ENTRYPOINT="${3:-cli}" "$HOOK" "$1" >"$T/out" 2>"$T/err"; }
prompt() { jq -n --arg s "$1" --arg p "$2" '{session_id:$s, prompt:$p}'; }
edit() { jq -n --arg s "$1" --arg f "$2" '{session_id:$s, tool_name:"Edit", tool_input:{file_path:$f}}'; }
bash_() { jq -n --arg s "$1" --arg c "$2" '{session_id:$s, tool_name:"Bash", tool_input:{command:$c}}'; }

# Arm on a real first ask, then block the first source edit once.
call --arm "$(prompt s1 'add a dark mode toggle to the settings page please')"; ok 0 $? "arm exits 0"
grep -q "asked-for:" "$T/out"; ok 0 $? "arm reminder names asked-for:"
call --gate "$(edit s1 /r/src/app.ts)"; ok 2 $? "first source edit without a restatement is blocked"
grep -q "asked-for:" "$T/err"; ok 0 $? "block message names asked-for:"
call --gate "$(edit s1 /r/src/app.ts)"; ok 0 $? "gate stands down after one block"

# A restatement before the edit means no block at all.
call --arm "$(prompt s2 'fix the login redirect bug on the account page')"
call --record "$(bash_ s2 'echo "asked-for: fix the redirect after login on the account page"')"
call --gate "$(edit s2 /r/src/login.ts)"; ok 0 $? "restated session is not blocked"

# A lazy restatement does not count.
call --arm "$(prompt s3 'refactor the billing module to use the new client')"
call --record "$(bash_ s3 'echo "asked-for: do it"')"
call --gate "$(edit s3 /r/src/billing.py)"; ok 2 $? "a two-word restatement does not count"

# Non-source files never block.
call --arm "$(prompt s4 'update the readme with the new install steps')"
call --gate "$(edit s4 /r/README.md)"; ok 0 $? "markdown edit is not gated"
call --gate "$(edit s4 /r/notes.txt)"; ok 0 $? "text edit is not gated"

# Continuation prompts belong to leg-scope.
call --arm "$(prompt s5 'Continue from the reboot handoff above and finish it')"
[ -s "$T/out" ]; ok 1 $? "continuation prompt injects nothing"
call --gate "$(edit s5 /r/src/x.ts)"; ok 0 $? "continuation session is not gated"

# Slash commands and tiny prompts do not arm.
call --arm "$(prompt s6 '/done')"
call --gate "$(edit s6 /r/src/x.ts)"; ok 0 $? "slash command does not arm"
call --arm "$(prompt s7 'yes')"
call --gate "$(edit s7 /r/src/x.ts)"; ok 0 $? "one-word prompt does not arm"

# Only the first ask arms. A later prompt does not re-arm a passed session.
call --arm "$(prompt s1 'now also add a keyboard shortcut for the toggle')"
call --gate "$(edit s1 /r/src/keys.ts)"; ok 0 $? "later prompt does not re-arm"

# Headless runs are never gated.
call --arm "$(prompt s8 'add a dark mode toggle to the settings page please')" sdk-ts
call --gate "$(edit s8 /r/src/app.ts)" sdk-ts; ok 0 $? "headless run is not gated"

# Kill switch.
printf '%s' "$(prompt s9 'add a dark mode toggle to the settings page please')" | CLAUDE_SKIP_HOOKS=restate-gate CLAUDE_CODE_ENTRYPOINT=cli RESTATE_GATE_STATE="$T/state" "$HOOK" --arm >/dev/null 2>&1
call --gate "$(edit s9 /r/src/app.ts)"; ok 0 $? "kill switch prevents arming"

# An apostrophe inside the restatement still counts.
call --arm "$(prompt s10 'add a dark mode toggle to the settings page please')"
call --record "$(bash_ s10 "echo \"asked-for: don't touch the API, just fix the settings toggle\"")"
call --gate "$(edit s10 /r/src/app.ts)"; ok 0 $? "apostrophe in restatement still counts"

# Parallel edits are blocked once in total, not once each.
call --arm "$(prompt s11 'add a dark mode toggle to the settings page please')"
for i in 1 2 3 4; do (printf '%s' "$(edit s11 /r/src/p$i.ts)" | env -u CLAUDE_SKIP_HOOKS -u OMC_SKIP_HOOKS RESTATE_GATE_STATE="$T/state" CLAUDE_CODE_ENTRYPOINT=cli "$HOOK" --gate >/dev/null 2>&1; echo $? > "$T/par$i") & done; wait
B=$(cat "$T"/par* | grep -c '^2$'); ok 1 "$B" "four parallel edits produce exactly one block"

# A short or slash opener does not switch the gate off for the real ask.
call --arm "$(prompt s12 'hey')"
call --arm "$(prompt s12 'add a dark mode toggle to the settings page please')"
call --gate "$(edit s12 /r/src/app.ts)"; ok 2 $? "real ask after a short opener still arms"

# A background notification is not an ask.
call --arm "$(prompt s13 '<task-notification> agent finished its review of the hook </task-notification>')"
call --gate "$(edit s13 /r/src/app.ts)"; ok 0 $? "task notification does not arm"

# Subagent edits are never blocked; the main session keeps its one block.
call --arm "$(prompt s14 'add a dark mode toggle to the settings page please')"
call --gate "$(jq -n '{session_id:"s14", agent_id:"sub1", tool_name:"Edit", tool_input:{file_path:"/r/src/a.ts"}}')"; ok 0 $? "subagent edit is not gated"
call --gate "$(jq -n '{session_id:"s14", tool_name:"Write", tool_input:{file_path:"/r/src/a.ts"}}')"; ok 2 $? "main session Write is still gated"

# Fail open on junk input.
call --gate 'not json'; ok 0 $? "bad json fails open"
call --gate "$(jq -n '{tool_name:"Edit", tool_input:{file_path:"/r/src/a.ts"}}')"; ok 0 $? "missing session id fails open"

# A short first ask followed by edits must not let a later prompt arm mid-task.
call --arm "$(prompt s15 'fix the flaky test')"
call --gate "$(edit s15 /r/src/flaky.ts)"
call --arm "$(prompt s15 'now also bump the CI node version please')"
call --gate "$(edit s15 /r/src/ci.ts)"; ok 0 $? "no mid-session arming after unarmed edits"

# Arrows and shell tails do not cut a restatement short.
call --arm "$(prompt s16 'add a dark mode toggle to the settings page please')"
call --record "$(bash_ s16 'echo "asked-for: fix the parser so a -> b maps to c" && git status')"
grep -qx 'fix the parser so a -> b maps to c' "$T/state/stated-s16"; ok 0 $? "arrow and && tail handled"

# A notification with leading whitespace still does not arm.
call --arm "$(prompt s17 '
<task-notification> agent finished its review of the hook </task-notification>')"
call --gate "$(edit s17 /r/src/app.ts)"; ok 0 $? "indented notification does not arm"

# Every outcome is logged so the gate can be measured later.
grep -q "blocked" "$T/state/log" && grep -q "stated" "$T/state/log"; ok 0 $? "log records blocked and stated"

rm -rf "$T"
echo "failures: $FAIL"; exit $FAIL
