#!/bin/bash
# Format checker: warns if an edited file has formatting issues
# Hook point: PostToolUse (matcher: "Edit|Write")
# Exit codes: 0=pass, 1=warn, 2=block

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0

# Only check formattable file types
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md) ;;
  *) exit 0 ;;
esac

# Only run if prettier is available in the project
if command -v npx &>/dev/null && [ -f "node_modules/.bin/prettier" ]; then
  OUTPUT=$(npx prettier --check "$FILE_PATH" 2>&1)
  if [ $? -ne 0 ]; then
    echo "Formatting issues in $FILE_PATH" >&2
    echo "Run: npx prettier --write \"$FILE_PATH\"" >&2
    exit 1
  fi
fi

exit 0
