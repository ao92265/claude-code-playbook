#!/bin/bash
# ESLint checker for PostToolUse hooks
# Only runs ESLint when a JS/TS file was edited
# Reads tool_input JSON from stdin

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if we couldn't extract a file path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Skip if not a JS/TS file
case "$FILE_PATH" in
  *.js|*.jsx|*.ts|*.tsx) ;;
  *) exit 0 ;;
esac

# Skip if no ESLint config exists
if ! ls .eslintrc* eslint.config.* >/dev/null 2>&1; then
  exit 0
fi

# Skip if ESLint is not installed
if [ ! -f node_modules/.bin/eslint ]; then
  exit 0
fi

# Run ESLint and capture output
OUTPUT=$(npx eslint --no-warn-ignored "$FILE_PATH" 2>&1 | head -20)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "$OUTPUT" >&2
  exit 2
fi

exit 0
