#!/bin/bash
# Build checker: runs TypeScript build with OOM prevention after edits
# Hook point: PostToolUse (matcher: "Edit|Write")
# Exit codes: 0=pass, 1=warn, 2=block

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0

# Only check TypeScript files
case "$FILE_PATH" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

# Only run if tsconfig.json exists
[ ! -f "tsconfig.json" ] && exit 0

# Run tsc with increased memory
OUTPUT=$(NODE_OPTIONS='--max-old-space-size=4096' npx tsc --noEmit 2>&1)
EXIT_CODE=$?

# If OOM, retry with more memory
if [ $EXIT_CODE -eq 134 ] || echo "$OUTPUT" | grep -q "FATAL ERROR.*heap"; then
  OUTPUT=$(NODE_OPTIONS='--max-old-space-size=8192' npx tsc --noEmit 2>&1)
  EXIT_CODE=$?
fi

if [ $EXIT_CODE -ne 0 ]; then
  echo "$OUTPUT" | head -20 >&2
  exit 2
fi

exit 0
