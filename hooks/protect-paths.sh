#!/bin/bash
# File protection: prevents Claude from modifying sensitive files without explicit permission
# Hook point: PreToolUse (matcher: "Edit|Write")
# Exit codes: 0=pass, 2=block
# Customize the PROTECTED array for your project

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
[ -z "$FILE" ] && exit 0

PROTECTED=(
  ".env"
  ".env.local"
  ".env.production"
  ".env.staging"
  ".env.development"
  "package-lock.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "prisma/schema.prisma"
)

for path in "${PROTECTED[@]}"; do
  if echo "$FILE" | grep -qF "$path"; then
    echo "BLOCKED: $FILE is a protected file and cannot be modified without explicit permission. Ask the developer first." >&2
    exit 2
  fi
done

exit 0
