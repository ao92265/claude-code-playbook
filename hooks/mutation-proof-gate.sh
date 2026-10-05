#!/usr/bin/env bash
# mutation-proof-gate.sh — PreToolUse(Bash): new tests must be shown to fail.
#
# Green is not evidence. A test that stays green when the thing it pins is broken
# tells you nothing, and both of the ones that blocked Scheduler PR #403 read
# perfectly well:
#
#   the assertion interpolated the same two symbols the production message
#   interpolates, so both sides moved together and the test could not fail for
#   the property its own docstring claimed
#
#   a [Theory] forbade four words lifted from the string being replaced, which
#   pins a snapshot of the old copy rather than the rule it describes
#
# Both survived three review rounds. The reviewers found them by running the
# mutations by hand. This gate asks for that proof up front, and
# ~/.claude/scripts/mutation-proof.sh produces it.
#
# It also carries one cheap static nudge for the tautology shape, deliberately
# low-confidence and deliberately an ask.
set -uo pipefail

# shellcheck source=lib/pr-gate-common.sh
# `dirname` is an external command, and the lib carries the notice that has to
# survive a PATH which cannot reach coreutils. Parameter expansion needs no PATH.
. "${BASH_SOURCE[0]%/*}/lib/pr-gate-common.sh"

GATE="mutation-proof-gate"
pg_read_input
pg_require_jq "$GATE"

[ "$PG_TOOL_NAME" = "Bash" ] || exit 0
case "$PG_COMMAND" in *"gh pr create"*) ;; *) exit 0 ;; esac

ROOT=$(pg_repo_root "gh pr create")
[ -d "$ROOT" ] || exit 0
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# The branch being shipped, which is not always the branch the shell sits on:
# a worktree PR is opened from a different checkout, and diffing the wrong one
# reports another piece of work's tests.
TIP=$(pg_head_branch)
if [ -n "$TIP" ] && ! git -C "$ROOT" rev-parse --verify --quiet "$TIP" >/dev/null 2>&1; then
  pg_notice "$GATE did not run: the branch ${TIP} could not be read in ${ROOT}, so no test diff was checked."
fi
TIP="${TIP:-HEAD}"

BASE=""
for b in origin/main origin/master main master; do
  git -C "$ROOT" rev-parse --verify --quiet "$b" >/dev/null 2>&1 && { BASE="$b"; break; }
done
# No base means no diff, and no diff means this gate cannot tell whether tests
# changed. That is unscannable, not clean.
[ -n "$BASE" ] || pg_cannot_run "$GATE" "no base branch was found to diff against"

TEST_FILES=$(git -C "$ROOT" diff --name-only "${BASE}...${TIP}" 2>/dev/null \
  | grep -iE '(^|/)(tests?|spec|__tests__)/|\.(spec|test)\.[jt]sx?$|Tests?\.cs$|_test\.(go|py)$|test_.*\.py$' || true)
[ -n "$TEST_FILES" ] || exit 0

# Test names added by this branch. Covers the shapes in play here: C# [Fact] /
# [Theory] methods, and the it()/test() of the JS runners.
# Fed in as an array, not a bare word split. A test path containing a space made
# the diff error out, the error went to /dev/null, and the gate stood down on a
# branch it had just decided was worth checking.
TEST_PATHS=()
while IFS= read -r tf; do [ -n "$tf" ] && TEST_PATHS+=("$tf"); done <<EOF
$TEST_FILES
EOF
ADDED=$(git -C "$ROOT" diff "${BASE}...${TIP}" -- "${TEST_PATHS[@]}" 2>/dev/null | grep '^+' || true)
NEW_TESTS=$(printf '%s' "$ADDED" \
  | grep -oE "(it|test)\(['\"\`][^'\"\`]+|public (async )?(void|Task) [A-Za-z_][A-Za-z0-9_]*" \
  | sed -E "s/^(it|test)\(['\"\`]//; s/^public (async )?(void|Task) //" \
  | sort -u || true)

LEDGER="$ROOT/.claude/evidence/mutations.jsonl"
HEAD_SHA=$(pg_tip_sha "$ROOT" "$TIP")

UNPROVEN=""
if [ -n "$NEW_TESTS" ]; then
  PROVEN=""
  [ -r "$LEDGER" ] && PROVEN=$(jq -r --arg h "$HEAD_SHA" 'select(.head == $h) | .test' "$LEDGER" 2>/dev/null || true)
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    # Whole line, not substring: the ledger stores full test names, and a proof
    # recorded for AddsAWidgetWhenLocked was marking a new AddsAWidget proven.
    printf '%s' "$PROVEN" | grep -qxF "$t" || UNPROVEN="$UNPROVEN
    $t"
  done <<EOF
$NEW_TESTS
EOF
fi

# The tautology shape: an added assertion whose expected value is built by
# interpolation rather than written as a literal. Low confidence on purpose —
# plenty of legitimate assertions interpolate — so it is reported alongside the
# real check rather than on its own.
TAUTOLOGY=$(printf '%s' "$ADDED" \
  | grep -inE 'Assert\.[A-Za-z]+\(\$"|Assert\.[A-Za-z]+\([A-Za-z_][A-Za-z0-9_.]*\.[A-Za-z]+\)|toBe\(`\$\{|toContain\(`\$\{|toEqual\(`\$\{' \
  | head -3 || true)

[ -n "$UNPROVEN$TAUTOLOGY" ] || exit 0

MSG="This branch adds tests that have not been shown to fail."
[ -n "$UNPROVEN" ] && MSG="$MSG

No mutation proof recorded at this commit for:${UNPROVEN}"
[ -n "$TAUTOLOGY" ] && MSG="$MSG

Possible tautology — the expected value is built the same way the code builds it, so both sides move together:
$(printf '%s' "$TAUTOLOGY" | sed 's/^/    /')"

# Ask once per branch per commit, not on every retry of the same command.
PG_ACK=$(pg_ack_path "$ROOT" "$TIP" "$TIP" "$MSG")
[ -f "$PG_ACK" ] && exit 0

pg_ask "${MSG}

Prove one with:
  ~/.claude/scripts/mutation-proof.sh --test '<name>' --file <production file> --sed '<expression that breaks it>' -- <test command>

It breaks the line, runs the suite, asserts that test goes red, restores the file byte-identical, and records the proof. If a test stays green under mutation, that is the finding.

Approve to open the PR anyway if these tests are genuinely covered elsewhere."
