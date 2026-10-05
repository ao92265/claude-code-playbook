#!/usr/bin/env bash
# pr-prior-round-gate.sh — PreToolUse(Bash): answer the last review before
# asking for the next one.
#
# Scheduler PR #403 went through two advisory review passes and then a third,
# blocking one. The third opened with a table headed "Prior-finding resolution"
# and the words NOT RESOLVED twice, against files that were byte-identical to
# where the previous round had left them. A whole review round was spent
# re-reporting findings nobody had answered.
#
# A finding can be fixed, or refused with a reason, or deferred to an issue. All
# three are fine. Leaving it unmentioned is the one that wastes a reviewer.
#
# The gate fires on the commands that hand a PR back to a human, reads the prior
# findings off the review, and asks when any of them has no status in the text
# going out.
set -uo pipefail

# shellcheck source=lib/pr-gate-common.sh
# `dirname` is an external command, and the lib carries the notice that has to
# survive a PATH which cannot reach coreutils. Parameter expansion needs no PATH.
. "${BASH_SOURCE[0]%/*}/lib/pr-gate-common.sh"

GATE="pr-prior-round-gate"
pg_read_input
pg_require_jq "$GATE"

# Every ask below goes through this, so the round is marked as asked. The gate
# owns the marker outright rather than waiting on a PostToolUse companion:
# hook registrations load at session start, so a companion would do nothing for
# any session already running, which is exactly where the repeated prompts were.
# The marker is now written by pg_ask, and only on the branch that actually
# stops a human. An auto session gets the same finding as a message it has to
# answer, and leaves the round unmarked for whoever looks next.
round_ask() { # round_ask <reason>
  # Keyed on the question, not just the round. A reviewer can post a second
  # CHANGES_REQUESTED with new findings while the branch has not moved, and a
  # round-wide ack would swallow it unread.
  PG_ACK=$(pg_ack_path "$ROOT" "$PR" HEAD "$1")
  [ -f "$PG_ACK" ] && exit 0
  pg_ask "$1"
}

[ "$PG_TOOL_NAME" = "Bash" ] || exit 0
# Only the verbs that carry text to a reviewer. `gh pr ready` and `gh pr merge`
# send no body, so pg_extract_body falls back to the raw command, every label
# reads as unanswered, and the ask fires every time while checking nothing.
case "$PG_COMMAND" in
  *"gh pr comment"*|*"gh pr edit"*|*"gh pr review"*) ;;
  *) exit 0 ;;
esac
command -v gh >/dev/null 2>&1 || pg_cannot_run "$GATE" "gh not found"

ROOT=$(pg_repo_root "gh pr")
cd "$ROOT" 2>/dev/null || exit 0

# PR number: an explicit argument wins, otherwise the branch's own PR.
PR=$(pg_pr_number)
[ -n "$PR" ] || exit 0

# The ack is checked inside round_ask, once the question is known. Asking the
# same question twice is the behaviour that had three panes stopped on the same
# prompt on 20 Aug, and a prompt that repeats is one people dismiss unread.

STATE=$(gh pr view "$PR" --json reviewDecision --jq '.reviewDecision // empty' 2>/dev/null || printf 'UNKNOWN')
# An unreachable PR is not a clean one. Say so rather than passing in silence.
[ "$STATE" = "UNKNOWN" ] && pg_cannot_run "$GATE" "the PR state could not be read"
[ "$STATE" = "CHANGES_REQUESTED" ] || exit 0

REVIEWS=$(gh api "repos/{owner}/{repo}/pulls/$PR/reviews" --jq '.[] | select(.state=="CHANGES_REQUESTED") | .body' 2>/dev/null || true)
INLINE=$(gh api "repos/{owner}/{repo}/pulls/$PR/comments" --jq 'length' 2>/dev/null || printf '0')
INLINE_FILES=$(gh api "repos/{owner}/{repo}/pulls/$PR/comments" --jq '.[].path' 2>/dev/null | sort -u || true)

# Finding labels as this repo's reviewers actually write them: "**H1 —**",
# "### M5", "High #1", "Medium #3". Normalised to a single form so the response
# can be searched for it however the author writes it back.
LABELS=$(printf '%s' "$REVIEWS" \
  | grep -oE '\*\*(H|M|L|C)[0-9]{1,2}\b|^#{2,4}[[:space:]]*(H|M|L|C)[0-9]{1,2}\b|(High|Medium|Low|Critical)[[:space:]]+#[0-9]+' \
  | sed 's/[*#]//g; s/^[[:space:]]*//; s/[[:space:]]\+/ /g' \
  | sed -E 's/^High ([0-9]+)$/H\1/; s/^Medium ([0-9]+)$/M\1/; s/^Low ([0-9]+)$/L\1/; s/^Critical ([0-9]+)$/C\1/' \
  | sort -u || true)

RESPONSE=$(pg_extract_body)
# A response written up as a file rather than inline still counts.
LEDGER="$ROOT/.claude/evidence/review-responses/pr-${PR}.md"
[ -r "$LEDGER" ] && RESPONSE="$RESPONSE
$(cat "$LEDGER")"

STATUS='(resolved|fixed|addressed|done|refus(ed|ing)|declin(ed|ing)|disagree|wontfix|won.t fix|deferred|not resolved|no change|out of scope|[0-9a-f]{7,40})'

# A finding labelled H1 in the review is answered whether the reply writes "H1",
# "High 1" or "High #1". Demanding the reviewer's exact spelling made the gate
# report a fully answered response as unanswered, which is the crying-wolf failure
# these gates exist to avoid (measured on PR #403, 20 Aug).
label_forms() { # label_forms <H1> -> an ERE alternation of every way it is written
  local l="$1" letter="${1%%[0-9]*}" num="${1#?}" word
  case "$letter" in
    H) word="High" ;; M) word="Medium" ;; L) word="Low" ;; C) word="Critical" ;;
    *) printf '%s' "$l"; return ;;
  esac
  printf '%s' "${l}|${word}[[:space:]]+#?${num}"
}

# Flattened to one line before matching. The matcher is line-oriented, so the
# ordinary markdown shape, a finding heading on one line and "Resolved in
# 5280e06." on the next, was read as unanswered. That is the same crying-wolf
# failure the bracket-expression fix above was written to kill.
FLAT=$(printf '%s' "$RESPONSE" | tr '\n' ' ')

MISSING=""
for l in $LABELS; do
  # Low findings are explicitly non-blocking in this repo's review format, so
  # they are reported as unanswered rather than demanded.
  printf '%s' "$FLAT" | grep -iqE "($(label_forms "$l"))\b.{0,160}${STATUS}" || MISSING="$MISSING $l"
done

if [ -z "$LABELS" ] && [ "${INLINE:-0}" -eq 0 ]; then
  # Nothing machine-readable to check against. Ask plainly rather than pretend.
  round_ask "PR #${PR} is in CHANGES_REQUESTED and its review carries no labelled findings this gate can enumerate.
Confirm by hand that every point the reviewer raised is either fixed, refused with a reason, or deferred to a named issue, and that the text going out says which."
fi

# Inline comments are findings too, and they have to be satisfiable or the gate
# becomes an ask that always fires and always gets approved. A response counts as
# answering them if it names each file they sit on, or says plainly that it has
# dealt with them.
UNANSWERED_FILES=""
if [ "${INLINE:-0}" -gt 0 ]; then
  if printf '%s' "$RESPONSE" | grep -iqE "inline comment[s]?.{0,60}${STATUS}"; then
    :
  else
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      printf '%s' "$RESPONSE" | grep -qF "$f" \
        || printf '%s' "$RESPONSE" | grep -qF "${f##*/}" \
        || UNANSWERED_FILES="$UNANSWERED_FILES
    $f"
    done <<EOF
$INLINE_FILES
EOF
  fi
fi

if [ -n "$MISSING" ] || [ -n "$UNANSWERED_FILES" ]; then
  DETAIL=""
  if [ -n "$MISSING" ]; then
    # A prompt is read at a glance or not at all. Thirteen labels on one line is
    # a wall; five and a count is a number the reader can act on.
    N=0; for l in $MISSING; do N=$((N+1)); done
    SHOWN=""; I=0
    for l in $MISSING; do I=$((I+1)); [ "$I" -le 5 ] && SHOWN="$SHOWN $l"; done
    [ "$N" -gt 5 ] && SHOWN="$SHOWN and $((N-5)) more"
    DETAIL="$DETAIL
${N} finding(s) have no status in the text going out:$SHOWN"
  fi
  [ -n "$UNANSWERED_FILES" ] && DETAIL="$DETAIL
Inline comments (${INLINE} in total) sit on files the response never mentions:${UNANSWERED_FILES}"

  round_ask "PR #${PR} is in CHANGES_REQUESTED.
${DETAIL}

Give each one a status: fixed (with the commit), refused (with the reason), or deferred (with the issue). All three are acceptable answers. Silence is the one that costs the reviewer a whole round, which is what happened on Scheduler #403.

Write the response to .claude/evidence/review-responses/pr-${PR}.md in the repo and this gate reads it, so the full answer can be longer than the comment going out. A scratch file outside the repo is invisible to it.

Approving here is remembered for this PR at this commit, so you will not be asked again until the branch moves."
fi

exit 0
