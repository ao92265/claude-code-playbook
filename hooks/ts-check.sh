#!/bin/bash
# Smart TypeScript checker for PostToolUse hooks
# Only runs tsc when an actual .ts/.tsx file was edited
# Reads tool_input JSON from stdin

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if we couldn't extract a file path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Skip if not a TypeScript file
case "$FILE_PATH" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

# Skip if no tsconfig.json in current directory
if [ ! -f tsconfig.json ]; then
  exit 0
fi

# Run tsc and capture output
OUTPUT=$(npx tsc --noEmit 2>&1 | head -20)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "$OUTPUT" >&2
  exit 2
fi

exit 0
