#!/bin/bash
# pr-prior-round-gate.sh: a PR in CHANGES_REQUESTED must answer each prior finding before the next comment goes out.
# gh is a stub driven by GH_* env vars; nothing touches the network.
source "$(dirname "$0")/lib.sh"
H=pr-prior-round-gate.sh
R="$TD/repo"; mkdir -p "$R"; git -C "$R" init -q . 
STUB="$TD/bin"; mkdir -p "$STUB"
cat > "$STUB/gh" <<'GH'
#!/bin/bash
case "$*" in
  "pr view"*reviewDecision*) [ -n "${GH_FAIL:-}" ] && exit 1; printf '%s' "${GH_DECISION:-}" ;;
  "api "*/reviews*)          printf '%s\n' "${GH_REVIEWS:-}" ;;
  "api "*/comments*length*)  echo "${GH_INLINE:-0}" ;;
  "api "*/comments*)         printf '%s\n' "${GH_FILES:-}" ;;
  *) exit 1 ;;
esac
GH
chmod +x "$STUB/gh"
export PR_GATE_ROOT="$R" PR_GATE_ACK_DIR="$TD/acks"
REV=$'**H1 \xe2\x80\x94 null deref**\n**M2 \xe2\x80\x94 naming**'
go() { run $H "$(bash_payload "$1")" "PATH=$STUB:$PATH" "${@:2}"; }
CR="GH_DECISION=CHANGES_REQUESTED"

go "ls -la" $CR "GH_REVIEWS=$REV";                         expect "non-PR command ignored" 0
expect_lacks "non-PR command silent" "$OUT" "permissionDecision"
go "gh pr ready 7" $CR "GH_REVIEWS=$REV";                  expect_lacks "verb without body ignored" "$OUT" "permissionDecision"
go "gh pr comment 7 --body 'hello'" "GH_DECISION=APPROVED"; expect_lacks "approved PR not gated" "$OUT" "permissionDecision"
go "gh pr comment 7 --body 'H1 fixed in abc1234'" $CR "GH_REVIEWS=$REV"
expect_has "unanswered finding asks" "$OUT" '"permissionDecision":"ask"'
expect_has "names the missing label" "$OUT" "M2"
expect_lacks "does not name the answered label" "$OUT" "have no status in the text going out: H1"
go "gh pr comment 7 --body 'H1 fixed in abc1234. M2 refused: naming is deliberate'" $CR "GH_REVIEWS=$REV"
expect_lacks "all findings answered passes" "$OUT" "permissionDecision"
go "gh pr comment 7 --body 'High #1 resolved. Medium 2 declined'" $CR "GH_REVIEWS=$REV"
expect_lacks "long-form labels count as answers" "$OUT" "permissionDecision"
go "gh pr comment 7 --body 'ok'" $CR "GH_REVIEWS=$REV" "GH_FAIL=1"
expect_has "unreadable PR says gate did not run" "$OUT" "did NOT run"
go "gh pr comment 7 --body 'ok'" $CR "GH_REVIEWS=plain prose no labels"
expect_has "no labels and no inline asks plainly" "$OUT" "no labelled findings"
go "gh pr comment 7 --body 'H1 fixed abc1234 M2 fixed abc1234'" $CR "GH_REVIEWS=$REV" "GH_INLINE=2" "GH_FILES=src/widget.ts"
expect_has "inline comment on unmentioned file asks" "$OUT" "src/widget.ts"
go "gh pr comment 7 --body 'H1 fixed abc1234 M2 fixed abc1234 widget.ts handled'" $CR "GH_REVIEWS=$REV" "GH_INLINE=2" "GH_FILES=src/widget.ts"
expect_lacks "mentioning the file answers inline comments" "$OUT" "permissionDecision"
mkdir -p "$R/.claude/evidence/review-responses"
echo "H1 fixed abc1234, M2 refused with a reason" > "$R/.claude/evidence/review-responses/pr-7.md"
go "gh pr comment 7 --body 'see ledger'" $CR "GH_REVIEWS=$REV"
expect_lacks "response ledger file counts" "$OUT" "permissionDecision"
rm "$R/.claude/evidence/review-responses/pr-7.md"
run $H "$(jq -c '. + {permission_mode:"bypassPermissions"}' <<<"$(bash_payload "gh pr comment 7 --body 'ok'")")" "PATH=$STUB:$PATH" $CR "GH_REVIEWS=$REV"
expect_has "bypass mode becomes a message, not an ask" "$OUT" "systemMessage"
expect_lacks "bypass mode does not ask" "$OUT" "permissionDecision"
finish
