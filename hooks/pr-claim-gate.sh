#!/usr/bin/env bash
# pr-claim-gate.sh — PreToolUse(Bash): every measurement in a PR body must come
# from a run that actually happened.
#
# On 19 Aug 2026 five Scheduler PRs were blocked in review. In all five the
# blocker was a claim in the PR text, not broken code:
#
#   "1216 passed"                        the repo-root run was 1718
#   "costs the shipped-JS budget nothing" it cost 87.53 kB and only dodged the gate
#   "fixtures copied from the SQL"        the one that mattered was invented
#   "noted on the issue"                  the issue had zero comments
#   "## Screenshots"                      no image was ever attached
#
# Each was found by a reviewer re-running the work in a detached worktree. That
# is the author's job being done twice, by the more expensive person.
#
# The gate checks three things a script can settle before a human reads the PR:
#   1. numbers with no run behind them at this commit
#   2. evidence the body promises but does not carry
#   3. deferrals with nowhere to land
#
# All three ASK rather than block. A false positive costs one keystroke; a gate
# people learn to bypass costs everything.
set -uo pipefail

# shellcheck source=lib/pr-gate-common.sh
# `dirname` is an external command, and the lib carries the notice that has to
# survive a PATH which cannot reach coreutils. Parameter expansion needs no PATH.
. "${BASH_SOURCE[0]%/*}/lib/pr-gate-common.sh"

GATE="pr-claim-gate"
pg_read_input
pg_require_jq "$GATE"

[ "$PG_TOOL_NAME" = "Bash" ] || exit 0
case "$PG_COMMAND" in
  *"gh pr create"*|*"gh pr edit"*) ;;
  *) exit 0 ;;
esac

MARKER="gh pr create"
case "$PG_COMMAND" in *"gh pr edit"*) MARKER="gh pr edit" ;; esac
ROOT=$(pg_repo_root "$MARKER")
# The branch being shipped, which is not always the branch the shell sits on.
# Evidence is stamped with the commit it was produced at, so looking it up at the
# wrong tip both misses real runs and lets an unrelated branch's run back numbers
# it never produced.
BRANCH=$(pg_head_branch)
BODY=$(pg_extract_body "$MARKER")
[ -n "$BODY" ] || exit 0

FINDINGS=""

# ---- 1. numbers with no run behind them -------------------------------------
#
# Only figures that assert a measurement. An issue number, a section reference
# and a date are not claims about the world's state, and asking about them would
# bury the ones that are.
# The decimal group is not optional decoration: without it "87.53 kB" is read as
# "53 kB", and the gate then asks about a number nobody wrote.
CLAIMS=$(printf '%s' "$BODY" | grep -oiE '[0-9][0-9,]*(\.[0-9]+)?[[:space:]]*(passed|failed|skipped|tests?|assertions?|kB|KB|MB|bytes)\b' | sort -u || true)
PHRASES=$(printf '%s' "$BODY" | grep -oiE 'all (tests|suites) pass(ing|ed)?|exit(ed)? (code )?0|CI PASS|all green|suites? (are )?green|0 failures?' | sort -u || true)

if [ -n "$CLAIMS$PHRASES" ]; then
  LEDGER=$(pg_evidence_file "$ROOT")
  HEAD_SHA=$(pg_tip_sha "$ROOT" "${BRANCH:-HEAD}")

  if [ ! -r "$LEDGER" ]; then
    FINDINGS="$FINDINGS
UNSUPPORTED NUMBERS — no verification runs are recorded for this repo at all.
The body states:
$(printf '%s\n%s' "$CLAIMS" "$PHRASES" | sed '/^$/d' | sed 's/^/    /' | head -8)
Nothing here was produced by a run this gate can see."
  else
    # A record made before the last commit describes different code. Stale and
    # absent are the same thing for the purpose of backing a claim.
    FRESH=$(jq -r --arg h "$HEAD_SHA" 'select(.head == $h) | .tail' "$LEDGER" 2>/dev/null || true)
    UNBACKED=""
    for c in $(printf '%s' "$CLAIMS" | grep -oE '^[0-9][0-9,]*(\.[0-9]+)?' | tr -d ',' | sort -u); do
      [ -n "$c" ] || continue
      # Fixed string, bounded by non-digits. Unanchored and unescaped, "1216
      # passed" was backed by any run whose output contained 121600, and the dot
      # in "87.53" matched any character, so 87953 backed it too.
      pat=$(printf '%s' "$c" | sed 's/[][\.*^$+?(){}|]/\\&/g')
      printf '%s' "$FRESH" | tr -d ',' | grep -qE "(^|[^0-9])${pat}([^0-9]|\$)" || UNBACKED="$UNBACKED $c"
    done
    if [ -n "$UNBACKED" ]; then
      FINDINGS="$FINDINGS
UNSUPPORTED NUMBERS — these figures appear in the body but in no run recorded at this commit:$UNBACKED
Recorded runs at $(printf '%s' "$HEAD_SHA" | cut -c1-7): $(jq -r --arg h "$HEAD_SHA" 'select(.head == $h) | .cmd' "$LEDGER" 2>/dev/null | sort -u | tr '\n' ';' | sed 's/;$//')"
    fi
  fi
fi

# ---- 2. evidence the body promises but does not carry -----------------------
#
# Scheduler PR #355 cleared every code finding and still could not merge, because
# its body owed screenshots it never attached. The repo's own working agreement
# requires them for any screen built without a Figma design.
PROMISE='(^#{1,6}.*screenshot|screenshots?[[:space:]]+(below|attached|here|of|in|show)|see the screenshot|screenshots?:)'
if printf '%s' "$BODY" | grep -qiE "$PROMISE"; then
  # Only a rendered image counts. A bare filename does not: GitHub renders
  # `01-locked-face.jpg` as the eleven characters of text it is. PR #355 listed
  # four such filenames in a table pointing at a folder in the repo, and the
  # reviewer's sole remaining blocker, after every code finding was fixed, was
  # "the screenshots this PR's own body says it owes".
  if ! printf '%s' "$BODY" | grep -qE '!\[|user-attachments|githubusercontent'; then
    NAMED=$(printf '%s' "$BODY" | grep -coE '\.(png|jpe?g|gif|webp)\b' || true)
    if [ "${NAMED:-0}" -gt 0 ]; then
      FINDINGS="$FINDINGS
PROMISED EVIDENCE NOT SHOWN — the body names ${NAMED} image file(s) but embeds none, so a reviewer sees filenames rather than screens."
    else
      FINDINGS="$FINDINGS
PROMISED EVIDENCE MISSING — the body talks about screenshots and carries no image.
$(printf '%s' "$BODY" | grep -inE "$PROMISE" | head -3 | sed 's/^/    /')"
    fi
  fi
fi

# ---- 3. deferrals with nowhere to land --------------------------------------
#
# PR #419 said an open question "is noted on the issue rather than invented here".
# The issue had zero comments. Nothing recorded it, and the PR's own closing
# keyword would have deleted the only surviving copy on merge.
#
# 'out of scope' is deliberately absent from the list below: it describes a past
# decision at least as often as a deferral ("Graph was ruled out of scope on
# 23 Jul"), and a gate that cries wolf on settled history is one people stop
# reading.
DEFERRALS=$(printf '%s' "$BODY" \
  | grep -inE 'deferred|defers|not fixed here|not fixed in this|follow-up|followup|remains open|still open|left for|noted on|raised on|will be done separately' \
  || true)

if [ -n "$DEFERRALS" ]; then
  UNANCHORED=$(printf '%s' "$DEFERRALS" | grep -vE '#[0-9]+' || true)
  [ -n "$UNANCHORED" ] && FINDINGS="$FINDINGS
DEFERRAL WITH NO ISSUE — these lines defer work and name no issue to track it:
$(printf '%s' "$UNANCHORED" | head -4 | sed 's/^/    /')"

  # "noted on #N" is a claim about the world, not a plan. Check it.
  if command -v gh >/dev/null 2>&1; then
    for n in $(printf '%s' "$DEFERRALS" | grep -oiE '(noted on|raised on)[^#]{0,20}#[0-9]+' | grep -oE '[0-9]+$' | sort -u); do
      count=$(cd "$ROOT" 2>/dev/null && gh issue view "$n" --json comments --jq '.comments | length' 2>/dev/null || printf 'x')
      [ "$count" = "0" ] && FINDINGS="$FINDINGS
CLAIM DOES NOT HOLD — the body says this is noted on issue #${n}. That issue has zero comments."
    done
  fi
fi

[ -n "$FINDINGS" ] || exit 0

# Ask once per branch per commit, rather than on every retry of the same post.
PG_ACK=$(pg_ack_path "$ROOT" "${BRANCH:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}" "${BRANCH:-HEAD}" "$FINDINGS")
[ -f "$PG_ACK" ] && exit 0

pg_ask "The PR body makes claims this gate could not confirm.
${FINDINGS}

Reviewers on this repo re-run the work to check figures like these, and on 19 Aug every blocked PR was blocked on one. Fix the body, or run the verification again so the numbers come from a real run, or approve if you know the claim holds.

To record a run outside a Claude session: ~/.claude/scripts/evidence.sh <command>"
