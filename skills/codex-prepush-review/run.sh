#!/usr/bin/env bash

# codex-prepush-review
#
# Usage:
#   ./run.sh <issue-number>
#
# Runs Codex to review changes for a given GitHub issue number.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <issue-number>" >&2
  exit 1
fi

ISSUE_NUM="$1"

if ! [[ "$ISSUE_NUM" =~ ^[0-9]+$ ]]; then
  echo "Error: issue-number must be an integer (got: $ISSUE_NUM)" >&2
  exit 1
fi

PROMPT="Look at issue #$ISSUE_NUM and then do a git status and where necessary git diff.
Goal: find likely bugs, missing edge cases, type-safety issues, Next.js server/client boundary mistakes, security issues, and missing tests.
Be strict on correctness; avoid large refactors unless necessary.
Output format:
1. Blockers - must-fix before push
2. Important - should-fix
3. Nits - optional
4. Missing tests - specific test cases
5. Questions for the author - only if truly needed"

RAW_OUT="$(mktemp -t codex-prepush-review.XXXXXX)"

codex exec --json "$PROMPT" | awk -v f="$RAW_OUT" '{
  print > f
  c++
  printf "\rlines: %d", c > "/dev/stderr"
} END { print "" > "/dev/stderr" }'

cat "$RAW_OUT" | jq -r 'select(.type=="item.completed" and .item.type=="agent_message") | .item.text'
