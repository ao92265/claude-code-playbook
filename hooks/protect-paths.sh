#!/bin/bash

# Honor OMC_SKIP_HOOKS env var (comma- or space-separated list of hook names to skip)
if echo "${OMC_SKIP_HOOKS:-}" | grep -qwE "protect-paths"; then
  exit 0
fi

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

PROTECTED=(
  ".env"
  ".env.local"
  ".env.production"
  "package-lock.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "prisma/schema.prisma"
)

for path in "${PROTECTED[@]}"; do
  if echo "$FILE" | grep -qF "$path"; then
    echo "Protected: $FILE cannot be modified without explicit permission. Ask the developer first." >&2
    exit 2
  fi
done

exit 0
