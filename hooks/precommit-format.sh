#!/bin/bash
# Pre-commit format + CRLF-normalize hook (global, opt-out).
# Fires on `git commit`: normalizes CRLF->LF on staged TEXT files and runs the
# repo's detected formatter, then re-stages. Catches the CRLF diff-churn and
# lint slop the insights report flagged. NON-BLOCKING by design — it fixes and
# re-stages, never aborts a commit (that stays the job of pre-commit-verify.sh).
#
# Opt-out:
#   - export DISABLE_PRECOMMIT_FORMAT=1
#   - or add `precommit-format` to CLAUDE_SKIP_HOOKS (comma-separated)
#   - or `[skip-format]` / `[wip]` in the commit message
# Per-repo override: if ./.claude/hooks/auto-format.sh exists it is delegated to
# and this hook does nothing else (repo owns its formatting).

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only act on `git commit`
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Bypasses
[ -n "$DISABLE_PRECOMMIT_FORMAT" ] && exit 0
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *",precommit-format,"*) exit 0 ;; esac
case "$COMMAND" in *"[skip-format]"*|*"[wip]"*|*"[skip-verify]"*|*"--amend"*) exit 0 ;; esac

# Must be inside a git work tree
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Per-repo override wins
if [ -x ./.claude/hooks/auto-format.sh ]; then
  ./.claude/hooks/auto-format.sh 2>/dev/null || true
  exit 0
fi

# Staged, added/copied/modified files
FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
[ -z "$FILES" ] && exit 0

CHANGED=""

# 1) CRLF -> LF on staged TEXT files only (git -I skips binary)
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # Text only: grep -I excludes binary (no match -> exit 1 -> skipped)
  if LC_ALL=C grep -Iq . "$f" 2>/dev/null; then
    if LC_ALL=C grep -lq $'\r' "$f" 2>/dev/null; then
      LC_ALL=C perl -i -pe 's/\r\n/\n/g' "$f" 2>/dev/null && CHANGED="$CHANGED $f"
    fi
  fi
done <<< "$FILES"

# 2) Detected formatter (best-effort, non-blocking)
run_prettier() {
  local bin=""
  if [ -x node_modules/.bin/prettier ]; then bin="node_modules/.bin/prettier"; fi
  [ -z "$bin" ] && return 0
  local pfiles
  pfiles=$(echo "$FILES" | grep -iE '\.(js|jsx|ts|tsx|json|css|scss|md|mdx|html|yml|yaml)$' || true)
  [ -z "$pfiles" ] && return 0
  echo "$pfiles" | while IFS= read -r f; do
    [ -f "$f" ] && "$bin" --write "$f" >/dev/null 2>&1 || true
  done
  CHANGED="$CHANGED $pfiles"
}
run_prettier

# 3) Re-stage anything we touched
if [ -n "$(git diff --name-only 2>/dev/null)" ]; then
  echo "$FILES" | while IFS= read -r f; do
    [ -f "$f" ] && git add -- "$f" 2>/dev/null || true
  done
  echo "precommit-format: normalized line endings / formatted staged files" >&2
fi

exit 0
