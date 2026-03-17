#!/bin/bash
# Enforce conventional commit message format
# Checks that git commit commands use conventional commit prefixes
# Reads tool_input JSON from stdin

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip if not a git commit command
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Extract the commit message from -m flag
MSG=$(echo "$COMMAND" | grep -oP '(?<=-m\s")[^"]+|(?<=-m\s'"'"')[^'"'"']+' | head -1)

# If we can't extract the message (heredoc, etc.), skip
if [ -z "$MSG" ]; then
  exit 0
fi

# Check for conventional commit prefix
VALID_PREFIXES="^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?:"

if ! echo "$MSG" | grep -qP "$VALID_PREFIXES"; then
  echo "Commit message doesn't follow conventional commit format." >&2
  echo "" >&2
  echo "Expected format: <type>(<scope>): <description>" >&2
  echo "" >&2
  echo "Valid types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  feat(auth): add JWT token refresh" >&2
  echo "  fix: resolve null pointer in user service" >&2
  echo "  docs: update API endpoint documentation" >&2
  echo "" >&2
  echo "Your message: $MSG" >&2
  exit 2
fi

exit 0
