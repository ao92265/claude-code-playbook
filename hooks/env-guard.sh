#!/bin/bash
# Environment guard: prevents committing .env files or secrets
# Hook point: PreToolUse (matcher: "Bash")
# Exit codes: 0=pass, 1=warn, 2=block

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check git add and git commit commands
case "$COMMAND" in
  *"git add"*|*"git commit"*) ;;
  *) exit 0 ;;
esac

# Check for .env files being staged
ENV_FILES=$(git diff --cached --name-only 2>/dev/null | grep -E '\.env(\.local|\.production|\.staging|\.development)?$')
if [ -n "$ENV_FILES" ]; then
  echo "BLOCKED: Environment files staged for commit:" >&2
  echo "$ENV_FILES" >&2
  echo "Remove with: git reset HEAD <file>" >&2
  exit 2
fi

# Check staged diffs for secret patterns
SECRETS=$(git diff --cached -U0 2>/dev/null | grep -E '^\+.*(AWS_SECRET|AWS_ACCESS_KEY|PRIVATE_KEY|api_key|apiKey|secret_key|secretKey|password\s*[=:]|DATABASE_URL|MONGO_URI)' | head -5)
if [ -n "$SECRETS" ]; then
  echo "BLOCKED: Potential secrets in staged changes:" >&2
  echo "$SECRETS" >&2
  echo "Move secrets to .env and add .env to .gitignore" >&2
  exit 2
fi

exit 0
