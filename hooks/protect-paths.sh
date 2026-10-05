#!/bin/bash

# Honor CLAUDE_SKIP_HOOKS env var (comma- or space-separated list of hook names to skip).
# OMC_SKIP_HOOKS is the legacy alias, still honoured.
if echo "${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}" | grep -qwE "protect-paths"; then
  exit 0
fi

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Committed templates (*.example, e.g. .env.example) carry no secrets and are meant
# to be edited/committed. Never protect them — the substring rules below would
# otherwise false-positive ".env.example" against the ".env" entry.
case "$(basename "$FILE")" in
  *.example) exit 0 ;;
esac

PROTECTED=(
  ".env"
  ".env.local"
  ".env.production"
  "package-lock.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "prisma/schema.prisma"
  "prisma/migrations"
  "credentials.json"
)

for path in "${PROTECTED[@]}"; do
  if echo "$FILE" | grep -qF "$path"; then
    echo "Protected: $FILE cannot be modified without explicit permission. Ask the developer first." >&2
    exit 2
  fi
done

exit 0
