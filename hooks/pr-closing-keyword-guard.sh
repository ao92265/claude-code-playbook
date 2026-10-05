#!/usr/bin/env bash
# pr-closing-keyword-guard.sh — PreToolUse(Bash): stop a PR auto-closing an
# issue it has not finished.
#
# GitHub closes an issue on merge when a body or commit message contains a
# closing verb followed by #N. Its parser sees the verb and the number and
# nothing else: negation, emphasis and surrounding prose are invisible to it.
#
# This is not theoretical. <your-org>/Scheduler PR #357 merged on 18 Aug 2026
# and auto-closed issue #320 one second later, from a body whose entire purpose
# was to say it deliberately did NOT finish that issue. The next day PR #415
# carried the same sentence shape ("Does not close #281") in its squash source,
# aimed at an issue that had by then absorbed two others. A reviewer caught it
# by hand. This gate is that reviewer's finding, automated.
#
# Verdicts:
#   DENY  — a negation sits within a few words of the verb/number pair. There is
#           no legitimate use of that form: it reads as a promise not to close
#           and behaves as an instruction to close. The fix is always `Refs #N`.
#   ASK   — the PR closes an issue while showing a sign that issue is not done:
#           unticked checkboxes on the issue, deferral language about that same
#           number, or the number carrying both a closing verb and `Refs`.
#   SILENT— a plain `Closes #N` with no counter-signal. The common, correct case
#           must stay frictionless or the gate gets routed around.
set -uo pipefail

# shellcheck source=lib/pr-gate-common.sh
# `dirname` is an external command, and the lib carries the notice that has to
# survive a PATH which cannot reach coreutils. Parameter expansion needs no PATH.
. "${BASH_SOURCE[0]%/*}/lib/pr-gate-common.sh"

GATE="pr-closing-keyword-guard"
pg_read_input
pg_require_jq "$GATE"

[ "$PG_TOOL_NAME" = "Bash" ] || exit 0
case "$PG_COMMAND" in
  *"gh pr create"*|*"gh pr edit"*|*"git commit"*) ;;
  *) exit 0 ;;
esac

MARKER="gh pr create"
case "$PG_COMMAND" in
  *"gh pr edit"*)  MARKER="gh pr edit" ;;
  *"git commit"*)  MARKER="git commit" ;;
esac
ROOT=$(pg_repo_root "$MARKER")

# Scan the PR text AND every commit message on the branch. The squash prefill is
# the first commit's body, so a keyword that never appears in the PR description
# still reaches main. #415's trap was in the commit, not the body.
#
# Which branch matters. `--head` names the one being shipped, and it is regularly
# not the one the shell sits on: worktree PRs are opened from a different
# checkout entirely. Reading the wrong branch is not a near miss, it reports
# another piece of work's issue numbers against this PR, which is what happened
# to the #474 PR on 21 Aug 2026.
TEXT=$(pg_extract_body "$MARKER")
BRANCH=""
NOTICE=""
case "$PG_COMMAND" in
  *"gh pr create"*)
    BRANCH=$(pg_head_branch)
    COMMITS=$(pg_branch_commits "$ROOT" "${BRANCH:-HEAD}")
    case $? in
      0) TEXT="$TEXT
$COMMITS" ;;
      1) NOTICE="the branch ${BRANCH} could not be read in ${ROOT}" ;;
      *) NOTICE="no base branch was found in ${ROOT} to compare ${BRANCH:-HEAD} against" ;;
    esac
    # Held, not raised. The commits going unread is worth saying, and it is not a
    # reason to stop: the trap this gate exists for lives in the body just as
    # often, and raising the notice here would exit before the body is scanned.
    ;;
esac

# Every quiet exit goes through this, so a half-scan is never reported as a clean
# one. A deny or an ask outranks it and leaves earlier.
finish() {
  [ -n "$NOTICE" ] && pg_notice "$GATE checked the PR body but not the commits on the branch: ${NOTICE}. A closing keyword in a commit message reaches main through the squash prefill, so that half is unchecked."
  exit 0
}

KEYWORD='(close[sd]?|fix(e[sd])?|resolve[sd]?)'
NEGATION='(not|never|no longer|doesn.t|don.t|cannot|can.t|partially|nor|neither|without)'

# One sentence per line, so a negation cannot reach across a full stop into an
# unrelated claim. The distance bound matters as much as the words: "Does not
# close #281" is nine characters, while an unbounded search would deny any long
# sentence that happened to contain "not" before a legitimate Closes.
SENTENCES=$(printf '%s' "$TEXT" | sed -E 's/([.!?])[[:space:]]+/\1'$'\\\n''/g')

NEGATED=$(printf '%s' "$SENTENCES" \
  | grep -inE "\b${NEGATION}\b[^.!?]{0,40}\b${KEYWORD}[[:space:]]+#[0-9]+" \
  | head -3 || true)

if [ -n "$NEGATED" ]; then
  pg_deny "This text tells GitHub to close an issue while saying in English that it does not.

$NEGATED

GitHub's parser reads only the verb and the number. It cannot see 'does not', backticks or surrounding prose, so on merge the issue closes anyway.

This has already happened here: Scheduler PR #357 auto-closed issue #320 on 18 Aug 2026 from exactly this sentence shape.

Fix: break the verb and the number apart. Write 'Refs #N' and say what remains, in both the PR body and every commit message on the branch (the squash prefill is a commit body)."
fi

# Which issues this text really will close.
CLOSING=$(printf '%s' "$TEXT" | grep -oiE "\b${KEYWORD}[[:space:]]+#[0-9]+" \
  | grep -oE '#[0-9]+' | sort -u | tr -d '#' || true)
[ -n "$CLOSING" ] || finish

REPO_ARG=""
[ -d "$ROOT" ] && REPO_ARG="$ROOT"

CONCERNS=""
for n in $CLOSING; do
  # Signal 1: the same number carries deferral language somewhere in the text.
  if printf '%s' "$SENTENCES" | grep -iqE "#${n}\b[^.!?]{0,120}(still open|remains|remaining|not finish|does not finish|deliberately|out of scope|follow-up|left open|absorbed)" \
  || printf '%s' "$SENTENCES" | grep -iqE "(still open|remains|remaining|not finish|out of scope|follow-up|left open|absorbed)[^.!?]{0,120}#${n}\b"; then
    CONCERNS="$CONCERNS
  #${n}: this text both closes it and says work on it remains."
  fi

  # Signal 2: the same number appears with a closing verb AND with Refs. One of
  # the two is wrong, and the closing verb is the one that takes effect.
  if printf '%s' "$TEXT" | grep -iqE "\brefs[[:space:]]+#${n}\b"; then
    CONCERNS="$CONCERNS
  #${n}: written as both 'Refs' and a closing keyword. Only the closing keyword takes effect."
  fi

  # Signal 3: the issue itself still has unticked checkboxes. Needs gh; when gh
  # is unreachable this check is skipped rather than guessed at, and the skip is
  # named in the prompt so silence never reads as "checked, clean".
  if command -v gh >/dev/null 2>&1; then
    body=$(cd "${REPO_ARG:-.}" 2>/dev/null && gh issue view "$n" --json body,title --jq '.body' 2>/dev/null || true)
    if [ -n "$body" ]; then
      open_boxes=$(printf '%s' "$body" | grep -cE '^[[:space:]]*[-*][[:space:]]+\[[[:space:]]\]' || true)
      if [ "${open_boxes:-0}" -gt 0 ]; then
        CONCERNS="$CONCERNS
  #${n}: the issue still has ${open_boxes} unticked checkbox(es)."
      fi
    fi
  fi
done

if [ -n "$CONCERNS" ]; then
  # Ask once per branch per commit. The gate had no memory of an answer, so every
  # retry of the same command asked the same question again, and a prompt that
  # repeats is one people clear without reading. Deliberately below the refusal
  # above: an ack records a human answering a judgment call, and the negated
  # keyword is not one.
  PG_ACK=$(pg_ack_path "$ROOT" "${BRANCH:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}" "${BRANCH:-HEAD}" "$CONCERNS")
  [ -f "$PG_ACK" ] && finish
  pg_ask "This will close issues on merge, and at least one looks unfinished:
${CONCERNS}

An issue closed early stops being on anyone's list. If the PR really does finish it, approve. If not, change that number to 'Refs #N' and say what remains and which issue tracks it."
fi

finish
