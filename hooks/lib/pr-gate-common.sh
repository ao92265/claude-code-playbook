#!/usr/bin/env bash
# pr-gate-common.sh — shared plumbing for the pre-PR evidence gates.
#
# Born 20 Aug 2026 from the five Scheduler PRs sitting in CHANGES_REQUESTED
# (#355 #403 #415 #418 #419). In 5 of 5 the merge blocker was a claim in the PR
# text that did not survive checking, not broken code. These gates check the
# claims before a reviewer has to.
#
# Conventions copied deliberately from Scheduler's own .claude/hooks/pre-pr-gate.sh
# (docs/decisions/2026-07-28-pre-pr-gate-fixes-and-ask.md and
#  docs/decisions/2026-08-11-pre-pr-gate-unscannable-means-ask.md):
#
#   * A gate that CANNOT scan says so. Exiting 0 in silence is the same signal
#     as "scanned, clean", and that ambiguity is the failure mode being guarded.
#   * Hits ASK rather than block, so a human decides on a false positive.
#     The one exception is the negated closing keyword, which has no legitimate
#     use and has already cost this repo an issue.
#   * A test seam (PR_GATE_ROOT) lets the smoke test drive the blocking path.
#
# Source this, do not execute it.

# ---------------------------------------------------------------- payload ----

# Read with a shell builtin, not `cat`: the "jq is missing" notice has to survive
# a PATH that cannot reach coreutils, which is exactly when jq is missing too.
# `read -d ''` consumes to EOF and reports failure there; that status is expected.
pg_read_input() {
  IFS= read -r -d '' PG_INPUT <&0 || true
  export PG_INPUT
}

# pg_cannot_run <gate name> <fixed, quote-free reason>
#
# Stand aside, but say so when a PR command is at stake. A hook that exits 0 has
# exactly one channel a human sees: a JSON systemMessage on stdout. Stderr on
# exit 0 reaches only `claude --debug`. Exiting non-zero would surface, but the
# docs label that a "hook error" and a missing jq must not look like a failure of
# the PR command itself.
#
# The JSON is assembled as a plain string on purpose: the usual builder is the
# very tool that may be missing. Both arguments must be fixed, quote-free
# literals. Never pass user data or command text through here, it is not escaped.
pg_cannot_run() {
  case "$PG_INPUT" in
    *"gh pr "*|*"git commit"*)
      echo "$1: $2 — the gate did NOT run, so nothing was checked." >&2
      printf '%s\n' "{\"systemMessage\":\"$1 did NOT run ($2). The PR text was NOT checked for unsupported claims, closing-keyword traps or unanswered review findings.\"}"
      ;;
  esac
  exit 0
}

# pg_require_jq <gate name> — every verdict below is built with jq.
pg_require_jq() {
  command -v jq >/dev/null 2>&1 || pg_cannot_run "$1" "jq not found"
  printf '%s' "$PG_INPUT" | jq -e . >/dev/null 2>&1 \
    || pg_cannot_run "$1" "the hook payload was not valid JSON"
  PG_TOOL_NAME=$(printf '%s' "$PG_INPUT" | jq -r '.tool_name // empty')
  PG_COMMAND=$(printf '%s' "$PG_INPUT" | jq -r '.tool_input.command // empty')
  PG_CWD=$(printf '%s' "$PG_INPUT" | jq -r '.cwd // empty')
  export PG_TOOL_NAME PG_COMMAND PG_CWD
}

# ---------------------------------------------------------------- verdicts ---

# pg_auto_on — true when this session has handed judgment calls to the agent.
#
# `/auto` and bypass permissions do not reach a hook verdict: a PreToolUse "ask"
# stops the human whatever mode the session is in. That is the right default for
# a gate nobody has thought about, and the wrong one for a session that has
# explicitly said "decide it yourself", which is where these prompts were piling
# up on 21 Aug 2026.
#
# `permission_mode` on the payload carries bypass. Verified against a live
# payload on 21 Aug 2026 rather than assumed; an absent field is simply not a
# bypass. Auto is auto-mode.py's own state file, read rather than duplicated,
# down to its eight hour life: a switch nobody turned off dies with the day.
# The session id comes from the payload only, never from the environment. A hook
# inherits CLAUDE_CODE_SESSION_ID from the shell it was launched in, so falling
# back to it would let the corpus read the live session's real switch.
pg_auto_on() {
  local mode key file
  mode=$(printf '%s' "$PG_INPUT" | jq -r '.permission_mode // empty' 2>/dev/null)
  [ "$mode" = "bypassPermissions" ] && return 0
  key=$(printf '%s' "$PG_INPUT" | jq -r '.session_id // empty' 2>/dev/null)
  [ -n "$key" ] || return 1
  key="${key//[^A-Za-z0-9_.-]/_}"; key="${key:0:80}"
  file="${PR_GATE_AUTO_DIR:-$HOME/.claude/state/auto}/${key}.json"
  [ -r "$file" ] || return 1
  jq -e --argjson life 28800 \
    '(.on == true) and ((now - (.since // 0)) < $life)' "$file" >/dev/null 2>&1
}

# pg_notice <message> — stand aside, but say what was not checked.
#
# The louder sibling of pg_cannot_run, for once jq is known to be present: it
# escapes properly, so it can carry a branch name or a path. Same contract, a
# gate that could not scan something says so rather than passing in silence.
pg_notice() {
  jq -cn --arg m "$1" '{systemMessage:$m}'
  exit 0
}

# pg_mark_ack <path> — record that this exact question was PUT to a human.
#
# Deliberately not the approval itself. A PreToolUse hook cannot see the answer,
# so writing the approval here would record a refusal as consent. This leaves a
# pending marker holding the command's digest, and pr-gate-ack-promote.sh turns
# it into the approval on PostToolUse, which fires only if the command ran.
pg_mark_ack() {
  [ -n "${1:-}" ] || return 0
  mkdir -p "${1%/*}" 2>/dev/null || true
  pg_digest "$PG_COMMAND" > "$1.pending" 2>/dev/null || true
}

# pg_ask <reason> — request a decision.
#
# Set PG_ACK to an ack path first and the question is asked once per round rather
# than on every retry. The marker is written only on the branch that actually
# stops a human, so it always means "someone answered this", never "this was
# never checked".
pg_ask() {
  if pg_auto_on; then
    # Auto is on, so the judgment is the agent's to make. Same finding, no
    # keypress. Exit 0 with a systemMessage: the command proceeds unless the
    # agent decides otherwise, and the agent has to say what it decided.
    jq -cn --arg reason "$1" \
      '{systemMessage:("PR GATE (this session decides its own judgment calls, so nobody approved this, you did):\n\n" + $reason + "\n\nDecide it. If you go ahead, say in your reply what you waved through and why that is right. If you do not, fix the text and run it again.")}'
    exit 0
  fi
  pg_mark_ack "${PG_ACK:-}"
  jq -cn --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
}

pg_deny() { # pg_deny <reason> — refuse outright. Reserved for defects with no legitimate form.
  jq -cn --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

# ---------------------------------------------------------------- repo root --

pg_resolve_dir() { # pg_resolve_dir <base> <path>
  (
    if [ -n "$1" ]; then cd "$1" 2>/dev/null || exit 1; fi
    cd "$2" 2>/dev/null && pwd
  )
}

pg_expand_home() { # expand only explicit leading home forms, without eval
  case "$1" in
    \~)       printf '%s\n' "$HOME" ;;
    \~/*)     printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
    \$HOME)   printf '%s\n' "$HOME" ;;
    \$HOME/*) printf '%s/%s\n' "$HOME" "${1#\$HOME/}" ;;
    *)        printf '%s\n' "$1" ;;
  esac
}

# pg_expand_var <word> — resolve $VAR or ${VAR} from an assignment in the same
# command, one level, no eval. A worktree PR is written as
# `WT=/path/to/tree` then `git -C "$WT" …`, all in one compound command, so the
# path is right there in the text and nowhere else this hook can reach.
# Anything that is not a plain name comes back untouched.
pg_expand_var() {
  local ref="$1" name value
  case "$ref" in
    \$\{*\}) name="${ref#\$\{}"; name="${name%\}}" ;;
    \$*)     name="${ref#\$}" ;;
    *)       printf '%s\n' "$ref"; return 0 ;;
  esac
  case "$name" in
    ''|*[!A-Za-z0-9_]*) printf '%s\n' "$ref"; return 0 ;;
  esac
  value=$(printf '%s' "$PG_COMMAND" \
    | grep -oE "(^|[[:space:];&|])${name}=(\"[^\"]*\"|'[^']*'|[^[:space:];&|]*)" | tail -1 \
    | sed -E "s/^[[:space:];&|]*${name}=//; s/^\"(.*)\"\$/\1/; s/^'(.*)'\$/\1/")
  [ -n "$value" ] && { pg_expand_home "$value"; return 0; }
  printf '%s\n' "$ref"
}

# pg_repo_root <verb-prefix-marker>
#
# The repo the command actually runs in. Several worktrees run at once, so the
# script's own location is wrong whenever the command runs elsewhere. Resolution:
#   1. PR_GATE_ROOT      — test seam, so the smoke test can exercise the real path
#   2. the last `cd`/`pushd` before the marker in the command text — worktree PRs
#      arrive as one compound command and this hook fires BEFORE that cd runs, so
#      only the command text can reveal the true target
#   3. the last `git -C <target>` in the command, resolving one level of $VAR
#   4. the harness-reported shell cwd
#   5. the current directory
#
# Step 3 exists because a worktree can be driven entirely by path. On 21 Aug 2026
# a PR opened with `WT=… ; git -C "$WT" status ; gh pr create --head …` and no cd
# anywhere sent this gate to the shell's own checkout, which was on an unrelated
# branch, and it reported that branch's issue numbers against the PR.
#
# Trailing whitespace is trimmed BEFORE the quotes: ERE alternation is
# leftmost-longest, so `[^&;|]+` out-matches `"[^"]+"` and the capture arrives
# with its trailing space. Strip the quotes first and the `"…"$` anchor never
# matches, leaving literal quotes in the path. The separator is [[:space:]]+ so a
# TAB between verb and target is not silently unmatched, and `pushd` is accepted
# because it moves the shell exactly as `cd` does.
pg_repo_root() {
  local marker="$1" cd_target git_c root
  if [ -n "${PR_GATE_ROOT:-}" ]; then
    printf '%s\n' "$PR_GATE_ROOT"; return 0
  fi
  cd_target=$(printf '%s' "${PG_COMMAND%%${marker}*}" \
    | grep -oE "\b(cd|pushd)[[:space:]]+(\"[^\"]+\"|'[^']+'|[^&;|]+)" | tail -1 \
    | sed -E 's/^[[:space:]]*(cd|pushd)[[:space:]]+//; s/[[:space:]]+$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')
  if [ -n "$cd_target" ]; then
    cd_target=$(pg_expand_var "$(pg_expand_home "$cd_target")")
    root=$(pg_resolve_dir "$PG_CWD" "$cd_target") && [ -n "$root" ] && { printf '%s\n' "$root"; return 0; }
  fi
  # Unlike the cd above, this is not bounded to the text before the marker: the
  # `git -C` that names the worktree often sits after the gh command in a
  # compound line, and it moves nothing, so its position carries no meaning.
  git_c=$(printf '%s' "$PG_COMMAND" \
    | grep -oE "\bgit[[:space:]]+-C[[:space:]]+(\"[^\"]+\"|'[^']+'|[^[:space:];&|]+)" | tail -1 \
    | sed -E 's/^git[[:space:]]+-C[[:space:]]+//; s/[[:space:]]+$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')
  if [ -n "$git_c" ]; then
    git_c=$(pg_expand_var "$(pg_expand_home "$git_c")")
    root=$(pg_resolve_dir "$PG_CWD" "$git_c") && [ -n "$root" ] && { printf '%s\n' "$root"; return 0; }
  fi
  [ -n "$PG_CWD" ] && { printf '%s\n' "$PG_CWD"; return 0; }
  pwd
}

# ---------------------------------------------------------------- PR text ----

# pg_extract_body — the PR/issue body text carried by the command, on stdout.
#
# Covers the forms actually used: --body/-b with a quoted string, a heredoc
# (`--body "$(cat <<'EOF' … EOF)"` arrives in the command text verbatim, so the
# whole command is the right thing to scan), and --body-file/-F pointing at a
# path. Rather than parse a shell command properly — which needs a shell — the
# body-file case reads the file, and every other case hands back the raw command.
# A superset is the safe direction here: scanning too much can only over-ask, and
# every gate quotes its hit back so a human can see a false positive instantly.
pg_extract_body() {
  local file scope="$PG_COMMAND" firstline
  # Bounded to the text after the gh verb when the caller names it, so a command
  # that runs something else afterwards cannot redirect the scan.
  if [ -n "${1:-}" ]; then
    case "$PG_COMMAND" in *"$1"*) scope="${PG_COMMAND#*$1}" ;; esac
  fi
  # `--body-file` belongs to gh and to nothing else, so it is safe to take from
  # anywhere in the scope. `-F` is also grep's fixed-string flag and git commit's
  # file flag, so it counts only on the gh line itself: a trailing
  # `grep -F pattern file` was winning the `tail -1` and sending the scan to a
  # file with no PR text in it at all.
  file=$(printf '%s' "$scope" \
    | grep -oE '(--body-file)[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' \
    | tail -1 | sed -E 's/^\(?--body-file\)?[[:space:]]+//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')
  if [ -z "$file" ]; then
    firstline="${scope%%$'\n'*}"
    file=$(printf '%s' "$firstline" \
      | grep -oE '(^|[[:space:]])-F[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)' \
      | tail -1 | sed -E 's/^[[:space:]]*-F[[:space:]]+//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')
  fi
  if [ -n "$file" ]; then
    file=$(pg_expand_home "$file")
    if [ -r "$file" ]; then cat "$file"; return 0; fi
  fi
  printf '%s' "$scope"
}

# pg_head_branch — the branch `gh pr create --head` names, or empty.
#
# The branch being shipped is not always the branch the shell sits on, and when
# they differ the shell's one is the wrong thing to read. A worktree branch is an
# ordinary ref, shared with every other checkout of the repo, so naming it is
# enough: no worktree path is needed to read its commits.
# Bounded to the text after `gh pr create`: `-H` is curl's header flag and
# grep's filename flag, and either can share a compound command with a PR.
pg_head_branch() {
  case "$PG_COMMAND" in *"gh pr create"*) ;; *) return 0 ;; esac
  printf '%s' "${PG_COMMAND#*gh pr create}" \
    | grep -oE "(--head|-H)[[:space:]]+(\"[^\"]+\"|'[^']+'|[^[:space:];&|]+)" | tail -1 \
    | sed -E 's/^(--head|-H)[[:space:]]+//; s/[[:space:]]+$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/'
}

# pg_branch_commits <repo root> [tip ref] — commit messages on that branch.
#
# The exit status is the point. 0 means the commits were read, whatever came
# back. 1 means the named branch does not resolve here. 2 means the repo itself
# could not be scanned: not a directory, not a git repo, or carrying none of the
# base branches this looks for. Every one of those used to come back as 0 with no
# output, which a caller reads as "scanned, clean", and a repo whose default
# branch is `develop` therefore passed a negated closing keyword in silence.
pg_branch_commits() {
  local root="$1" tip="${2:-HEAD}" base
  [ -d "$root" ] || return 2
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || return 2
  git -C "$root" rev-parse --verify --quiet "$tip" >/dev/null 2>&1 || return 1
  for base in origin/main origin/master main master; do
    if git -C "$root" rev-parse --verify --quiet "$base" >/dev/null 2>&1; then
      git -C "$root" log --format=%B "${base}..${tip}" 2>/dev/null && return 0
    fi
  done
  return 2
}

# ---------------------------------------------------------------- evidence ---

# pg_evidence_file <repo root> — where the ledger lives for this repo.
pg_evidence_file() { printf '%s/.claude/evidence/runs.jsonl\n' "$1"; }

# pg_head_sha <repo root>
pg_head_sha() { git -C "$1" rev-parse HEAD 2>/dev/null || true; }

# pg_tip_sha <repo root> [ref] — the sha of the branch actually being shipped,
# which is what makes an ack key mean "this round of this work" rather than
# "whatever the shell was sitting on".
pg_tip_sha() { git -C "$1" rev-parse "${2:-HEAD}" 2>/dev/null || true; }

# ---------------------------------------------------------------- acks -------
#
# A gate that asks the same question every retry stops being a gate and becomes
# a keypress. Three panes were sitting on the same prompt on 20 Aug because the
# prior-round gate had no memory of the human who had already answered it.
#
# What the marker actually records, as of 21 Aug 2026, is "this exact question
# was put to a human at this commit", not "a human approved it". It is written
# when the ask is issued, because a hook cannot see the answer, and there is no
# PostToolUse companion promoting it. The gap that leaves: decline an ask, re-run
# the identical command, and it goes through. Closing it needs a PostToolUse
# promoter, which is a settings change, so it is the user's call rather than a
# silent one. Until then, do not read an ack as consent.

# pg_pr_number — the PR the command names, or the branch's own. Empty if neither.
pg_pr_number() {
  local pr
  pr=$(printf '%s' "$PG_COMMAND" \
    | grep -oE 'gh pr (comment|edit|review|ready|merge)[[:space:]]+[0-9]+' \
    | grep -oE '[0-9]+$' | head -1)
  [ -n "$pr" ] || pr=$(gh pr view --json number --jq '.number' 2>/dev/null || true)
  printf '%s' "$pr"
}

# pg_ack_path <repo root> <pr number or branch> [ref] — the approved marker.
#
# Keyed on the commit as well as the PR: a new commit is a new round of the
# review, and a new round is worth asking about again. PR_GATE_ACK_DIR is the
# test seam. The key is built with parameter expansion so it needs no PATH.
#
# A PR being created has no number yet, so its branch name stands in. Slashes in
# a branch name would make a path rather than a file name, hence the scrub on
# both halves of the key.
pg_ack_path() {
  local dir base key sha tag
  dir="${PR_GATE_ACK_DIR:-$HOME/.claude/state/pr-gate-acks}"
  base="${1##*/}"; base="${base//[^A-Za-z0-9._-]/_}"
  key="${2//[^A-Za-z0-9._-]/_}"
  sha=$(pg_tip_sha "$1" "${3:-HEAD}"); sha="${sha:-nohead}"
  tag=""
  [ -n "${4:-}" ] && tag="-$(pg_digest "$4")"
  printf '%s/%s-%s-%s%s\n' "$dir" "$base" "$key" "$sha" "$tag"
}

# pg_digest <text> — a short stable stamp for the question being asked.
#
# Without it the ack is per round, so approving one finding would silence a
# different finding raised later at the same commit: a PR body can be rewritten
# without the sha moving. Collision resistance is not the job here, telling two
# questions apart is.
pg_digest() {
  local out
  out=$(printf '%s' "$1" | cksum 2>/dev/null) || out=""
  out="${out%% *}"
  printf '%s' "${out:-0}"
}
