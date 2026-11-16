#!/bin/bash
# pr-claim-gate.sh: a PR body's numbers, promised screenshots and deferrals must be backed; otherwise it asks.
source "$(dirname "$0")/lib.sh"
H=pr-claim-gate.sh
R="$TD/repo"; mkdir -p "$R"; cd "$R" || exit 1
git init -q -b main . && git config user.email t@example.com && git config user.name t
echo a > a; git add -A; git commit -qm init
STUB="$TD/bin"; mkdir -p "$STUB"
cat > "$STUB/gh" <<'GH'
#!/bin/bash
case "$*" in
  "issue view"*) echo "${GH_ISSUE_COMMENTS:-1}" ;;
  *) exit 1 ;;
esac
GH
chmod +x "$STUB/gh"
export PR_GATE_ROOT="$R" PR_GATE_ACK_DIR="$TD/acks"
go() { run $H "$(bash_payload "$1")" "PATH=$STUB:$PATH" "${@:2}"; }
ledger() { mkdir -p "$R/.claude/evidence"; jq -nc --arg h "$(git -C "$R" rev-parse HEAD)" --arg t "$1" '{head:$h,tail:$t,cmd:"npm test"}' > "$R/.claude/evidence/runs.jsonl"; }
ASKED() { [[ "$OUT" == *'"permissionDecision":"ask"'* ]]; }

go "ls";                                                   expect_lacks "non-PR command ignored" "$OUT" "permissionDecision"
go "gh pr create --title t --body 'Adds a widget.'";       expect_lacks "body with no claims passes" "$OUT" "permissionDecision"
go "gh pr create --title t --body '1216 passed'"
expect_has "numbers with no ledger ask" "$OUT" "UNSUPPORTED NUMBERS"
rm -rf "$TD/acks"
ledger "Tests: 1216 passed, 0 failed"
go "gh pr create --title t --body '1216 passed'";          expect_lacks "number backed by a run at HEAD passes" "$OUT" "permissionDecision"
go "gh pr create --title t --body '1217 passed'"
expect_has "number absent from the run asks" "$OUT" "1217"
rm -rf "$TD/acks"
ledger "Tests: 121600 passed"
go "gh pr create --title t --body '1216 passed'"
expect_has "substring of a bigger number does not back it" "$OUT" "UNSUPPORTED NUMBERS"
rm -rf "$TD/acks"
go "gh pr create --title t --body 'Screenshots below.'"
expect_has "promised screenshots with no image ask" "$OUT" "PROMISED EVIDENCE"
rm -rf "$TD/acks"
go "gh pr create --title t --body 'Screenshots below.
![shot](https://github.com/user-attachments/x.png)'"
expect_lacks "embedded image satisfies the promise" "$OUT" "permissionDecision"
go "gh pr create --title t --body 'Follow-up work is deferred.'"
expect_has "deferral with no issue asks" "$OUT" "DEFERRAL WITH NO ISSUE"
rm -rf "$TD/acks"
go "gh pr create --title t --body 'Follow-up tracked in #12.'"
expect_lacks "deferral naming an issue passes" "$OUT" "DEFERRAL WITH NO ISSUE"
go "gh pr create --title t --body 'Open question is noted on #12 later.'" GH_ISSUE_COMMENTS=0
expect_has "noted-on issue with zero comments is flagged" "$OUT" "CLAIM DOES NOT HOLD"
rm -rf "$TD/acks"

# the ask is remembered only once the command actually ran (see pr-gate-ack-promote)
go "gh pr create --title t --body '5 passed'"; ASKED && ok=1 || ok=0
[ "$ok" = 1 ] && { pass=$((pass+1)); echo "ok   first ask issued"; } || { fail=$((fail+1)); echo "FAIL first ask issued"; }
go "gh pr create --title t --body '5 passed'"; ASKED && ok=1 || ok=0
[ "$ok" = 1 ] && { pass=$((pass+1)); echo "ok   unanswered ask repeats"; } || { fail=$((fail+1)); echo "FAIL unanswered ask repeats"; }
run pr-gate-ack-promote.sh "$(bash_payload "gh pr create --title t --body '5 passed'")" PR_GATE_ACK_DIR="$TD/acks"
go "gh pr create --title t --body '5 passed'"
expect_lacks "ask stays quiet after the command ran" "$OUT" "permissionDecision"
run $H "$(jq -c '. + {permission_mode:"bypassPermissions"}' <<<"$(bash_payload "gh pr create --title t --body '7 passed'")")" "PATH=$STUB:$PATH"
expect_has "bypass mode becomes a message" "$OUT" "systemMessage"
expect_lacks "bypass mode does not ask" "$OUT" "permissionDecision"
finish
