#!/bin/bash
# mutation-proof-gate.sh: a PR that adds tests with no recorded mutation proof at HEAD asks before `gh pr create`.
source "$(dirname "$0")/lib.sh"
H=mutation-proof-gate.sh
mk() { # mk <dir> <base-branch>
  mkdir -p "$1"; git -C "$1" init -q -b "$2" . ; git -C "$1" config user.email t@example.com; git -C "$1" config user.name t
  echo a > "$1/a.txt"; git -C "$1" add -A; git -C "$1" commit -qm init
}
R="$TD/repo"; mk "$R" main
git -C "$R" checkout -qb feat
mkdir -p "$R/tests"
printf "it('adds a widget when locked', () => { expect(f()).toBe(1) })\n" > "$R/tests/w.test.js"
git -C "$R" add -A; git -C "$R" commit -qm "add test"
export PR_GATE_ACK_DIR="$TD/acks"
reset_acks() { rm -r "$TD/acks" 2>/dev/null; true; }
go() { run $H "$(bash_payload "$1")" PR_GATE_ROOT="$R" "${@:2}"; }
prove() { mkdir -p "$R/.claude/evidence"; jq -nc --arg h "$(git -C "$R" rev-parse HEAD)" --arg t "$1" '{head:$h,test:$t}' > "$R/.claude/evidence/mutations.jsonl"; }
PR="gh pr create --title t --body b"

go "ls";                                   expect_lacks "non-PR command ignored" "$OUT" "permissionDecision"
go "$PR"
expect_has "unproven new test asks" "$OUT" '"permissionDecision":"ask"'
expect_has "names the test" "$OUT" "adds a widget when locked"
reset_acks
prove "adds a widget"
go "$PR"; expect_has "partial-name proof does not count" "$OUT" "adds a widget when locked"
reset_acks
prove "adds a widget when locked"
go "$PR"; expect_lacks "exact proof at HEAD passes" "$OUT" "permissionDecision"
echo "x" > "$R/b.txt"; git -C "$R" add -A; git -C "$R" commit -qm more
go "$PR"; expect_has "proof recorded at an older commit is stale" "$OUT" '"permissionDecision":"ask"'
reset_acks

# no test files in the diff
R2="$TD/repo2"; mk "$R2" main; git -C "$R2" checkout -qb feat; echo b > "$R2/src.txt"; git -C "$R2" add -A; git -C "$R2" commit -qm src
run $H "$(bash_payload "$PR")" PR_GATE_ROOT="$R2"; expect_lacks "no test changes passes" "$OUT" "permissionDecision"

# no base branch to diff against: says it did not run, never silent
R3="$TD/repo3"; mk "$R3" dev
run $H "$(bash_payload "$PR")" PR_GATE_ROOT="$R3"; expect_has "no base branch is reported" "$OUT" "did NOT run"
run $H "$(bash_payload "$PR")" PR_GATE_ROOT="$TD/not-a-repo"; expect "not a repo exits 0" 0
finish
