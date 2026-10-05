#!/usr/bin/env bash
# branch-guard.sh — PreToolUse hook (Edit|Write|MultiEdit|NotebookEdit).
#
# Why: wrong_approach / wrong-branch is the joint-top friction (myinsights
# 2026-07-24, 45/202). The expensive mistakes land at EDIT time, before push —
# push-verify (workflow-rules PR Merge Authorization) is too late. This surfaces
# the live branch + dirty state on the FIRST edit to a given repo per session so
# a wrong-branch/wrong-worktree run is caught before code accretes there.
#
# Mostly advisory: a hook cannot know the "intended" branch, so the branch/dirty
# report does not block. It injects the ground truth next to the edit and lets the
# model stop if it mismatches. Fires ONCE per (session, repo) to stay quiet.
# The ONE blocking case is a live shared-tree collision (see below), which is a
# fact rather than a guess. Isolation discipline scored 35/100 on the calibrated
# myinsights scorecard (2026-08-18): 35 of 204 sessions ran isolated.
# Silent outside git repos (so ~/.claude/** direct edits never nag).
#
# Disable: CLAUDE_SKIP_HOOKS=branch-guard  (or BRANCH_GUARD_DISABLED=1)
# OMC_SKIP_HOOKS is the legacy alias, still honoured.
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,branch-guard,*) exit 0 ;; esac
[ "${BRANCH_GUARD_DISABLED:-0}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)

# ── Push mode (Bash matcher) ────────────────────────────────────────────────────
# The edit-time check below cannot catch every collision, and on 19 Aug 2026 it
# missed the one that mattered: a session working DETACHED in its own worktree has
# no branch to compare, so it matched nothing and pushed to a branch another live
# session owned. The push refspec is the first place the true target is stated, so
# it is checked here regardless of what HEAD says.
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
if [ -n "$CMD" ]; then
  # Only a real invocation, never the words in passing. Matched at command position:
  # start of line, or after a shell separator, with git's own flags allowed between
  # "git" and "push". A substring match reds `echo "git push ..."`, this hook's own
  # tests and any doc example that quotes the command (measured, 19 Aug 2026).
  printf '%s' "$CMD" \
    | grep -Eq '(^|[;&|]|&&|\|\||[[:space:]]&&[[:space:]]|^[[:space:]]*)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git([[:space:]]+-[^[:space:]]+)*[[:space:]]+push([[:space:]]|$)' \
    || exit 0
  PDIR=$(pwd)
  PREPO=$(git -C "$PDIR" rev-parse --show-toplevel 2>/dev/null || true)
  [ -z "$PREPO" ] && exit 0
  # Target branch, in the order the refspec states it:
  #   "HEAD:name" / "local:name" -> the part after the colon
  #   "git push origin name"     -> the trailing bare ref
  #   neither                    -> whatever HEAD currently is
  TARGET=$(printf '%s' "$CMD" | sed -n 's/.*[[:space:]][^[:space:]]*:\([A-Za-z0-9._/-]\{1,\}\).*/\1/p' | head -1)
  [ -z "$TARGET" ] && TARGET=$(printf '%s' "$CMD" | sed -n 's/.*git[[:space:]]\{1,\}push[[:space:]]\{1,\}\(--[^[:space:]]*[[:space:]]\{1,\}\)*[A-Za-z0-9._-]\{1,\}[[:space:]]\{1,\}\([A-Za-z0-9._/-]\{1,\}\).*/\2/p' | head -1)
  [ -z "$TARGET" ] && TARGET=$(git -C "$PREPO" symbolic-ref --short -q HEAD 2>/dev/null || true)
  [ -z "$TARGET" ] && exit 0
  PCOMMON=$(git -C "$PREPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  SELF=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
  OWNERS=""
  for f in "$HOME/.claude/sessions"/*.json; do
    [ -f "$f" ] || continue
    P=$(jq -r '.pid // empty' "$f" 2>/dev/null); [ -z "$P" ] && continue
    kill -0 "$P" 2>/dev/null || continue
    S=$(jq -r '.sessionId // empty' "$f" 2>/dev/null)
    [ -n "$SELF" ] && [ "$S" = "$SELF" ] && continue
    C=$(jq -r '.cwd // empty' "$f" 2>/dev/null); [ -z "$C" ] && continue
    CC=$(git -C "$C" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
    [ "$CC" = "$PCOMMON" ] || continue
    # Same working tree as the pusher is NOT a collision, and treating it as one
    # made this check fire on every push from a shared checkout (19 Aug 2026: three
    # sessions open in ~/Repos/acmeco/Scheduler, two of them read-only, blocked
    # every push and escalated to the user each time). The branch below is read from the
    # peer's cwd, so a peer that merely SITS in my checkout reports whatever branch
    # I put that checkout on: it cannot be on a different one, and it is not
    # evidence the peer is working on it. The cross-worktree case this check exists
    # for is unaffected, and same-tree collisions are the edit-time half's job.
    PT=$(git -C "$C" rev-parse --show-toplevel 2>/dev/null || true)
    [ -n "$PT" ] && [ "$PT" = "$PREPO" ] && continue
    B=$(git -C "$C" symbolic-ref --short -q HEAD 2>/dev/null || true)
    [ -z "$B" ] && B=$(jq -r '.branch // empty' "$f" 2>/dev/null)
    [ "$B" = "$TARGET" ] || continue
    OWNERS="${OWNERS:+$OWNERS, }$(jq -r '.name // .sessionId // "unnamed"' "$f" 2>/dev/null) (pid $P)"
  done
  if [ -n "$OWNERS" ]; then
    echo "branch-guard: BLOCKED. This push targets \`${TARGET}\`, and another live session is on that branch: ${OWNERS}." >&2
    echo "Both of you may be in your own worktrees and still collide: the branch is the shared resource, not the directory." >&2
    echo "MESSAGE THEM FIRST — run ListAgents, then SendMessage to the name above and agree who owns the branch. Then either let them push, or push a different branch. Override only if the user has said the branch is yours: CLAUDE_SKIP_HOOKS=branch-guard" >&2
    exit 2
  fi
  exit 0
fi

FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[ -z "$FILE" ] && exit 0
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-'); SID=${SID:-default}

# Resolve the repo containing the target file (dir of the file, since new files
# may not exist yet). Silent if not inside a git work tree.
DIR=$(dirname "$FILE" 2>/dev/null || echo .)
REPO=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || true)
[ -z "$REPO" ] && exit 0

# symbolic-ref resolves the branch name even on an unborn branch (no commits);
# fall back to a short SHA when HEAD is detached.
BRANCH=$(git -C "$REPO" symbolic-ref --short -q HEAD 2>/dev/null \
  || git -C "$REPO" rev-parse --short HEAD 2>/dev/null \
  || echo '?')
DIRTY=$(git -C "$REPO" status --porcelain 2>/dev/null | grep -c . || true); DIRTY=${DIRTY:-0}
# Flag a linked worktree (common-dir contains /worktrees/ only for linked trees).
WT=""
case "$(git -C "$REPO" rev-parse --git-common-dir 2>/dev/null)" in
  *"/worktrees/"*) WT=" [linked worktree]" ;;
esac

# Shared-tree collision: another LIVE session sitting in the same repo. Two agents
# editing one checkout is the failure behind both shared-tree memories, and
# Anthropic's multiagent work (13 Aug 2026) found same-machine agents escalate to
# sabotaging each other rather than noticing the conflict. Cheap to detect here:
# the session board carries a cwd per live pid.
#
# Repo identity is the COMMON git dir, not the checkout path (19 Aug 2026). Linked
# worktrees of one repository have different toplevels, so a toplevel comparison
# calls two sessions unrelated when they share every branch and one remote. That is
# exactly how the collision below got missed: both sessions were correctly in their
# own worktrees, and both were aimed at the same pull request.
#
# Peers are split into two buckets, because worktree parallelism is the ADVICE and
# must not be blocked:
#   SAME_BRANCH  — a peer whose branch is ours. The real collision. Blocks.
#   SAME_REPO    — a peer elsewhere in this repo. Fine. Advisory only.
SAME_BRANCH=""
SAME_REPO=""
BOARD_DIR="$HOME/.claude/sessions"
SELF_SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
COMMON=$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
if [ -d "$BOARD_DIR" ] && [ -n "$COMMON" ]; then
  for f in "$BOARD_DIR"/*.json; do
    [ -f "$f" ] || continue
    PID=$(jq -r '.pid // empty' "$f" 2>/dev/null) || continue
    [ -z "$PID" ] && continue
    kill -0 "$PID" 2>/dev/null || continue
    PSID=$(jq -r '.sessionId // empty' "$f" 2>/dev/null)
    [ -n "$SELF_SID" ] && [ "$PSID" = "$SELF_SID" ] && continue
    PCWD=$(jq -r '.cwd // empty' "$f" 2>/dev/null)
    [ -z "$PCWD" ] && continue
    PCOMMON=$(git -C "$PCWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
    [ "$PCOMMON" = "$COMMON" ] || continue
    PNAME=$(jq -r '.name // .sessionId // "unnamed"' "$f" 2>/dev/null)
    # The peer's EFFECTIVE branch. A detached peer reports no symbolic ref, so fall
    # back to the branch its recorded intent names — a detached worktree still pushes
    # somewhere, and that push target is what collides.
    PBRANCH=$(git -C "$PCWD" symbolic-ref --short -q HEAD 2>/dev/null || true)
    [ -z "$PBRANCH" ] && PBRANCH=$(jq -r '.branch // empty' "$f" 2>/dev/null)
    if [ -n "$PBRANCH" ] && [ "$PBRANCH" = "$BRANCH" ]; then
      SAME_BRANCH="${SAME_BRANCH:+$SAME_BRANCH, }${PNAME} (pid $PID)"
    else
      SAME_REPO="${SAME_REPO:+$SAME_REPO, }${PNAME} on ${PBRANCH:-detached} (pid $PID)"
    fi
  done
fi

# A live peer on the SAME BRANCH is the ONE case this hook blocks on. It is an
# unambiguous machine-checkable fact (not a guess about intent), and it has cost
# real work three times: the scheduler and TeamPlanner shared-tree memories both
# record a concurrent session reverting or racing live edits, and on 19 Aug 2026 two
# sessions in separate worktrees both pushed to one pull request. Advisory was not
# enough, so this exits 2. It deliberately does NOT write the once-per-session
# mark: the block must persist until the branch is actually no longer shared.
# Override for a branch you know is yours: CLAUDE_SKIP_HOOKS=branch-guard
if [ -n "$SAME_BRANCH" ]; then
  echo "branch-guard: BLOCKED. Another live session is on this same branch (${REPO##*/}, branch ${BRANCH}): ${SAME_BRANCH}." >&2
  echo "Separate worktrees do NOT fix this: git refuses one branch in two worktrees, so the second session detaches and both still push to the same branch. One session per branch is the rule." >&2
  echo "Do one of: (a) MESSAGE THE PEER FIRST — run ListAgents, then SendMessage to the name above, and agree who owns this branch; (b) take a different branch off origin/main in your own worktree; (c) wait for it to finish; (d) confirm with the user the branch is yours and re-run with CLAUDE_SKIP_HOOKS=branch-guard." >&2
  exit 2
fi

# Once per (session, repo), for the non-blocking advisory below.
STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR" 2>/dev/null || true
KEY=$(printf '%s' "$REPO" | tr -c 'A-Za-z0-9' '_' | tail -c 80)
MARK="$STATE_DIR/branchguard-${SID}-${KEY}"
[ -f "$MARK" ] && exit 0
: > "$MARK" 2>/dev/null || true

# A peer elsewhere in this repo is normal and allowed: worktree parallelism is the
# advice. Named anyway, because knowing who else is in here is what makes SendMessage
# usable instead of discovering the overlap from a surprise commit.
NEIGHBOURS=""
[ -n "$SAME_REPO" ] && NEIGHBOURS=" Also live in this repo (different branches, not a conflict): ${SAME_REPO}. Message them with SendMessage before taking work that touches theirs."

echo "<system-reminder>branch-guard: first edit in ${REPO##*/} this session. Branch \`${BRANCH}\`${WT}, ${DIRTY} uncommitted file(s). Confirm this is the intended target branch/worktree BEFORE editing (workflow-rules Branch & Worktree Safety). If wrong branch, stop and switch, do not build here. Multi-PR or shared tree means an isolated worktree off origin/main.${NEIGHBOURS}</system-reminder>"
exit 0
