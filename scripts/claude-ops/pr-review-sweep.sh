#!/bin/bash
# pr-review-sweep.sh — review every open PR that has not been reviewed yet.
#
# Every review is POSTED, own repos and shared alike (the user's call, 6 Aug 2026 —
# the approval inbox made him the bottleneck and he cleared it rather than keep
# feeding it). Reviews are always event=COMMENT, never APPROVE or
# REQUEST_CHANGES, so an unattended post cannot gate anyone's merge. Set
# Shared repos are parked in the inbox by default; set POST_SHARED_REPOS=1 to post there too.
#
# Usage:
#   pr-review-sweep.sh [--dry-run] [--limit N] [--only <slug#n>]
#
#   --dry-run   review everything, post nothing, park it all
#   --limit N   stop after N PRs this run (default 20)
#   --only      one PR, ignore the queue (for testing)
#
# Parked reviews land in ~/.claude/pr-review/pending/ with an INBOX.md index.
# Approve one with:
#   ~/.claude/scripts/pr-review-post.sh --pr <slug>#<n> \
#     --findings ~/.claude/pr-review/pending/<slug>-<n>/findings.json \
#     --summary  ~/.claude/pr-review/pending/<slug>-<n>/summary.md --post
#
# Exit codes: 0 ok (including "nothing to do") · 2 usage/precondition

set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# macOS keychain blocks background processes, so gh needs a token from env here
if [ -z "${GH_TOKEN:-}" ] && [ -f "$HOME/.config/pr-fleet.env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.config/pr-fleet.env"
fi

OWNED_OWNERS="<your-gh-user>"

# 1 = post shared-repo reviews unattended too. 0 = park them in the inbox.
POST_SHARED_REPOS="${POST_SHARED_REPOS:-0}"

# Repos whose PRs are never worth a review. badge-farm is a personal sandbox
# carrying 60+ open one-line-text-file PRs; project-a-cert-* are throwaway
# certification scratch repos. Without this the sweep spends its whole budget
# reviewing files that say "109".
IGNORED_REPO_PATTERNS="<your-gh-user>/badge-farm <your-gh-user>/project-a-cert- <your-org>/<repo>"

# A PR smaller than this has nothing to review. #31 (a docs retro) was +122, so
# the cutoff sits far below anything with an argument in it.
MIN_CHANGED_LINES=5

# The marker pr-review-post.sh stamps on every review body. Its presence is how
# a PR is recognised as already reviewed, so re-runs are cheap and quiet.
MARKER="Automated review via"

PENDING_DIR="$HOME/.claude/pr-review/pending"
INBOX="$HOME/.claude/pr-review/INBOX.md"
LOG_DIR="$HOME/logs"
POSTER="$HOME/.claude/scripts/pr-review-post.sh"

DRY_RUN=0
LIMIT=20
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --limit)   LIMIT="${2:-20}"; shift 2 ;;
    --only)    ONLY="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v gh >/dev/null || { echo "gh not found" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq not found" >&2; exit 2; }
command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 2; }
[ -x "$POSTER" ] || { echo "Missing $POSTER" >&2; exit 2; }

mkdir -p "$PENDING_DIR" "$LOG_DIR"
TS=$(date +%F-%H%M)
LOG="$LOG_DIR/pr-review-sweep-${TS}.log"

log() { echo "$*" | tee -a "$LOG"; }

# macOS ships no `timeout` and coreutils is not installed here, so a wedged
# review would otherwise hold the whole sweep open forever. Watchdog in bash:
# run the command, kill it if it outlives the budget.
run_with_timeout() {
  local budget="$1"; shift
  "$@" &
  local pid=$!
  (
    sleep "$budget"
    kill -0 "$pid" 2>/dev/null && kill -TERM "$pid" 2>/dev/null
    sleep 5
    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
  ) 2>/dev/null &
  local watchdog=$!
  wait "$pid"
  local status=$?
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  return "$status"
}

log "=== PR review sweep $TS (dry-run=$DRY_RUN limit=$LIMIT) ==="

# ------------------------------------------------------------------- the queue
# Authored-by-me and review-requested-of-me, deduplicated. Drafts are skipped:
# a draft is not asking for an opinion yet.
QUEUE=$(mktemp)
trap 'rm -f "$QUEUE"' EXIT

is_ignored() {
  local slug="$1" pattern
  for pattern in $IGNORED_REPO_PATTERNS; do
    case "$slug" in "$pattern"*) return 0 ;; esac
  done
  return 1
}

if [ -n "$ONLY" ]; then
  printf '%s\n' "$ONLY" > "$QUEUE"
else
  # Ordered by whose time it costs: a PR waiting on YOUR review first, then
  # other people's repos, then your own. A budget that runs out should run out
  # on your sandbox, not on a colleague's PR.
  RAW_QUEUE=$(mktemp)
  {
    gh search prs --review-requested=@me --state=open --draft=false --limit 40 \
      --json repository,number --jq '.[] | "0\t\(.repository.nameWithOwner)#\(.number)"' 2>/dev/null
    gh search prs --author=@me --state=open --draft=false --limit 100 \
      --json repository,number \
      --jq '.[] | (if (.repository.nameWithOwner | startswith("<your-gh-user>/")) then "2" else "1" end)
                  + "\t\(.repository.nameWithOwner)#\(.number)"' 2>/dev/null
  } | sort -u -k2,2 | sort -s -k1,1 > "$RAW_QUEUE"

  IGNORED=0
  while IFS=$'\t' read -r _rank ref; do
    [ -n "$ref" ] || continue
    if is_ignored "${ref%%\#*}"; then
      IGNORED=$((IGNORED + 1))
      continue
    fi
    printf '%s\n' "$ref"
  done < "$RAW_QUEUE" > "$QUEUE"
  rm -f "$RAW_QUEUE"
  [ "$IGNORED" -gt 0 ] && log "Skipped $IGNORED PR(s) in ignored repos ($IGNORED_REPO_PATTERNS)"
fi

TOTAL=$(wc -l < "$QUEUE" | tr -d ' ')
log "Open PRs in scope: $TOTAL"

REVIEWED=0; SKIPPED=0; POSTED=0; PARKED=0; FAILED=0

while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  [ "$REVIEWED" -ge "$LIMIT" ] && { log "Limit $LIMIT reached — stopping. Remaining PRs wait for the next run."; break; }

  SLUG="${ref%%\#*}"
  NUM="${ref##*\#}"
  OWNER="${SLUG%%/*}"

  # Too small to have an opinion about. Checked with one cheap API call, before
  # a whole Claude run gets spent finding out the diff is a single line.
  SIZE=$(gh pr view "$NUM" --repo "$SLUG" --json additions,deletions \
           --jq '.additions + .deletions' 2>/dev/null || echo 0)
  if [ "${SIZE:-0}" -lt "$MIN_CHANGED_LINES" ]; then
    log "· $ref — ${SIZE} changed line(s), too small to review"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Already reviewed? The marker survives new commits, so a PR is reviewed once
  # unless its parked findings are cleared. Re-review after a push is a manual
  # call — pr-review-post.sh's own duplicate suppression makes that safe.
  if gh api "repos/$SLUG/pulls/$NUM/reviews" --jq '.[].body' 2>/dev/null | grep -qF "$MARKER"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  WORK="$PENDING_DIR/${OWNER}-${SLUG#*/}-${NUM}"
  if [ -f "$WORK/findings.json" ]; then
    log "· $ref — already parked, awaiting your go"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  mkdir -p "$WORK"

  log "· $ref — reviewing"
  REVIEWED=$((REVIEWED + 1))

  # The review PRINTS its result rather than writing it. That keeps the whole
  # headless pass read-only — which matters because settings.json sets
  # defaultMode=plan, and a session that inherits plan mode cannot write a file
  # but can happily read a diff and report. This script writes the files.
  #
  # Posting stays here too, so a misread prompt can never comment on a PR.
  PROMPT="Review GitHub pull request ${SLUG}#${NUM}. This is a READ-ONLY review.

Method: fetch the metadata and the diff with gh, read surrounding source from the local
checkout if the repository is checked out anywhere under ~/Repos, and review for
correctness, silent failures, missing test coverage, and security. See
~/.claude/skills/pr-review/SKILL.md steps 1 to 5 for the full method.

Do NOT write or edit any file. Do NOT post anything to GitHub. Do NOT propose a plan or
ask for approval — nobody is reading this session. Print your result and stop.

Your final message must be ONE fenced json block and nothing else, in this shape:

\`\`\`json
{
  \"summary\": \"Two or three sentences on what the PR does and what the review found, then the counts by severity. Say so if you could not read surrounding source.\",
  \"findings\": [
    {\"path\": \"<repo-relative path exactly as it appears in the diff>\",
     \"line\": <line number in the NEW version of the file>,
     \"severity\": \"critical\",
     \"problem\": \"<one sentence>\",
     \"fix\": \"<one sentence>\"}
  ]
}
\`\`\`

Max 12 findings, most severe first. severity is critical, important or suggestion. Only
report a finding you can point at a specific changed line for. Use an empty findings
array if the PR is clean."

  RAW="$WORK/agent-output.txt"

  # The agent reads untrusted PR text, so it gets no general shell: only the two
  # read-only gh calls it needs. Anything else is denied in -p mode.
  if ! run_with_timeout 900 claude -p "$PROMPT" \
        --allowedTools "Bash(gh pr view:*),Bash(gh pr diff:*),Read(~/Repos/**),Grep(~/Repos/**),Glob(~/Repos/**)" \
        --disallowedTools "AskUserQuestion,Edit,Write,WebFetch,Read(~/.ssh/**),Read(~/.aws/**),Read(~/.config/**),Read(**/.env*)" \
        --output-format text >"$RAW" 2>&1; then
    log "  ! review failed or timed out — leaving $ref for the next run"
    cat "$RAW" >>"$LOG" 2>/dev/null
    rm -rf "$WORK"
    FAILED=$((FAILED + 1))
    continue
  fi
  cat "$RAW" >>"$LOG"

  # Pull the LAST fenced json block out of the transcript — the agent may show
  # intermediate blocks while it works, and the final one is the answer.
  awk '
    /^```json/ { collecting = 1; buf = ""; next }
    /^```/     { if (collecting) { last = buf; collecting = 0 }; next }
    collecting { buf = buf $0 "\n" }
    END        { printf "%s", last }
  ' "$RAW" > "$WORK/result.json"

  if ! jq -e '.findings | type == "array"' "$WORK/result.json" >/dev/null 2>&1; then
    log "  ! no parseable result — leaving $ref for the next run (transcript in $LOG)"
    rm -rf "$WORK"
    FAILED=$((FAILED + 1))
    continue
  fi

  jq '.findings' "$WORK/result.json" > "$WORK/findings.json"
  jq -r '.summary // "Automated review."' "$WORK/result.json" > "$WORK/summary.md"

  COUNT=$(jq 'length' "$WORK/findings.json")
  printf '%s\n' "$ref" > "$WORK/pr.ref"

  # An empty review is not worth a comment on anyone's PR.
  if [ "$COUNT" -eq 0 ]; then
    log "  clean — nothing to report"
    rm -rf "$WORK"
    continue
  fi

  OWNED=0
  case " $OWNED_OWNERS " in *" $OWNER "*) OWNED=1 ;; esac

  # Never post agent output that looks like a credential: the PR text is untrusted
  # and could have talked the agent into quoting one.
  if grep -qE 'ghp_|gho_|github_pat_|AKIA[0-9A-Z]{12}|-----BEGIN|sk-[A-Za-z0-9]{20}' \
       "$WORK/findings.json" "$WORK/summary.md" 2>/dev/null; then
    log "  ! output matched a secret pattern, parked instead"
    PARKED=$((PARKED + 1))
    continue
  fi

  if { [ "$OWNED" -eq 1 ] || [ "$POST_SHARED_REPOS" -eq 1 ]; } && [ "$DRY_RUN" -eq 0 ]; then
    if "$POSTER" --pr "$ref" --findings "$WORK/findings.json" \
                 --summary "$WORK/summary.md" --post >>"$LOG" 2>&1; then
      log "  posted $COUNT finding(s) → https://github.com/$SLUG/pull/$NUM"
      rm -rf "$WORK"
      POSTED=$((POSTED + 1))
    else
      log "  ! post failed — parked instead"
      PARKED=$((PARKED + 1))
    fi
  else
    log "  parked $COUNT finding(s) — shared repo, needs your go"
    PARKED=$((PARKED + 1))
  fi
done < "$QUEUE"

# ------------------------------------------------------------------- the inbox
{
  echo "# PR reviews awaiting your go"
  echo
  echo "_Updated $(date '+%F %H:%M'). Shared repos only — your own are posted automatically._"
  echo

  found=0
  for dir in "$PENDING_DIR"/*/; do
    [ -f "$dir/pr.ref" ] || continue
    found=1
    ref=$(cat "$dir/pr.ref")
    slug="${ref%%\#*}"; num="${ref##*\#}"
    crit=$(jq '[.[] | select(.severity == "critical")] | length' "$dir/findings.json" 2>/dev/null || echo 0)
    imp=$(jq '[.[] | select(.severity == "important")] | length' "$dir/findings.json" 2>/dev/null || echo 0)
    tot=$(jq 'length' "$dir/findings.json" 2>/dev/null || echo 0)

    echo "## [$ref](https://github.com/$slug/pull/$num)"
    echo
    echo "$tot finding(s) — $crit critical, $imp important."
    echo
    head -4 "$dir/summary.md" 2>/dev/null | sed 's/^/> /'
    echo
    echo '```bash'
    echo "~/.claude/scripts/pr-review-post.sh --pr $ref \\"
    echo "  --findings $dir/findings.json \\"
    echo "  --summary $dir/summary.md --post"
    echo '```'
    echo
  done

  [ "$found" -eq 0 ] && echo "Nothing waiting. All clear."
} > "$INBOX"

log "=== done: $REVIEWED reviewed · $POSTED posted · $PARKED parked · $SKIPPED skipped · $FAILED failed ==="
log "Inbox: $INBOX"
