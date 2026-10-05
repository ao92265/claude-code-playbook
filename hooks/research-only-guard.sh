#!/usr/bin/env bash
# research-only-guard.sh
#
# PreToolUse hook (registered for Edit|Write|NotebookEdit AND Bash). Enforces
# research-only mode mechanically while the sentinel file
# `.claude/state/research-only.flag` exists in the working directory.
#
#   - Edit / Write / NotebookEdit       → always blocked (findings only).
#   - Bash that MUTATES state           → blocked (npm install/test, git commit/push/add,
#                                         rm/mv/cp/mkdir/touch, output redirects, build/test
#                                         runners, package installs, etc.).
#   - Bash that is READ-ONLY            → allowed (git log/diff/status, ls, cat, grep, rg,
#                                         find, head/tail/wc, gh pr view, echo w/o redirect).
#
# The /research-only skill creates the flag on entry and removes it on clean exit;
# the babysitting/keyword detector can also arm it. Flag absent → no-op.
#
# Exit codes: 0 allow · 2 block (CC hook-denial convention)
set -uo pipefail

flag=".claude/state/research-only.flag"
[ -f "$flag" ] || exit 0

INPUT=$(cat 2>/dev/null || true)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

block() {
  cat >&2 <<MSG
[research-only-guard] BLOCKED — research-only mode is active.

$1

Sentinel: .claude/state/research-only.flag
Deliver findings as markdown instead. To exit research-only mode:
  rm .claude/state/research-only.flag
MSG
  exit 2
}

# No command field → this is an Edit/Write/NotebookEdit call. Always block.
if [ -z "$CMD" ]; then
  block "Edit / Write / NotebookEdit are disabled in research-only mode."
fi

# Bash path: strip quoted strings/heredocs so we don't match text inside args.
STRIPPED=$(echo "$CMD" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" | sed '/<<.*EOF/,/EOF/d')

# Output redirection (skip the 2>&1 / 2>/dev/null fd-dup forms) or tee → disk write.
if echo "$STRIPPED" | grep -qE '(^|[^0-9])>>?[[:space:]]*[^&]|[[:space:]]tee([[:space:]]|$)'; then
  block "That Bash command writes to disk (redirect / tee). Read-only analysis only."
fi

# In-place stream edits (sed -i / gsed -i). Note: read-only flags like 'grep -i' are fine.
if echo "$STRIPPED" | grep -qE '(^|[;&|[:space:]])(sed|gsed)[[:space:]]([^|;&]*[[:space:]])?-i'; then
  block "In-place edit (sed -i) writes to disk. Read-only analysis only."
fi

# Script interpreters can run arbitrary mutations — disallowed in research-only.
if echo "$STRIPPED" | grep -qE '(^|[;&|[:space:]])(python3?|node|deno|bun|ruby|perl|bash|sh|zsh)[[:space:]]' \
   || echo "$STRIPPED" | grep -qE '(^|[;&|[:space:]])\.?/[^[:space:]]+\.(sh|py|js|ts|rb|pl)([[:space:]]|$)'; then
  block "Running a script/interpreter can mutate state. Read-only analysis only."
fi

# Mutating verbs / tooling.
if echo "$STRIPPED" | grep -qE '(^|[;&|[:space:]])(rm|mv|cp|mkdir|touch|ln|chmod|chown|dd|truncate)([[:space:]]|$)'; then
  block "That Bash command mutates the filesystem. Read-only analysis only."
fi
if echo "$STRIPPED" | grep -qE 'git[[:space:]]+(commit|push|add|merge|rebase|reset|restore|checkout|stash|apply|cherry-pick|am|tag|mv|rm|clean|switch)([[:space:]]|$)'; then
  block "That git subcommand mutates state. Allowed read-only git: log/diff/status/show."
fi
if echo "$STRIPPED" | grep -qE '(npm|pnpm|yarn|bun)[[:space:]]+(i|install|add|ci|test|run|exec|publish|update|build)([[:space:]]|$)'; then
  block "Package-manager install/test/build/run mutates or executes. Read-only analysis only."
fi
if echo "$STRIPPED" | grep -qE '(^|[;&|[:space:]])(pip|pip3|poetry|uv|pdm|cargo|go|make|cmake|tsc|jest|vitest|pytest|gradle|mvn|docker|kubectl|terraform)([[:space:]]|$)'; then
  block "Build/test/deploy tooling is disabled in research-only mode. Read-only analysis only."
fi
if echo "$STRIPPED" | grep -qE 'gh[[:space:]]+(pr|issue|release|repo)[[:space:]]+(create|edit|merge|close|comment|delete|review|ready|upload)([[:space:]]|$)' \
   || echo "$STRIPPED" | grep -qiE 'gh[[:space:]]+api[^|;&]*(-X|--method)[[:space:]]+(POST|PUT|PATCH|DELETE)'; then
  block "That gh command writes to GitHub. Allowed read-only: 'gh pr view', 'gh pr list', GET-only 'gh api'."
fi

# Read-only Bash — allow.
exit 0
