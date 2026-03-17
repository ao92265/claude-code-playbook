#!/bin/bash
# Auto-run relevant tests when source files are edited
# Finds the corresponding test file and runs it
# Reads tool_input JSON from stdin

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if we couldn't extract a file path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Skip test files themselves (avoid infinite loops)
case "$FILE_PATH" in
  *.test.*|*.spec.*|*__tests__*|*_test.go|*_test.rs) exit 0 ;;
esac

# Skip non-source files
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs) ;;
  *) exit 0 ;;
esac

# Find the corresponding test file
DIR=$(dirname "$FILE_PATH")
BASE=$(basename "$FILE_PATH")
NAME="${BASE%.*}"
EXT="${BASE##*.}"

TEST_FILE=""

# TypeScript / JavaScript test patterns
if [ "$EXT" = "ts" ] || [ "$EXT" = "tsx" ] || [ "$EXT" = "js" ] || [ "$EXT" = "jsx" ]; then
  for pattern in "$DIR/$NAME.test.$EXT" "$DIR/$NAME.spec.$EXT" "$DIR/__tests__/$NAME.$EXT" "$DIR/__tests__/$NAME.test.$EXT"; do
    if [ -f "$pattern" ]; then
      TEST_FILE="$pattern"
      break
    fi
  done

  if [ -n "$TEST_FILE" ]; then
    # Detect test runner
    if [ -f "node_modules/.bin/vitest" ]; then
      OUTPUT=$(npx vitest run "$TEST_FILE" 2>&1 | tail -10)
    elif [ -f "node_modules/.bin/jest" ]; then
      OUTPUT=$(npx jest "$TEST_FILE" --no-coverage 2>&1 | tail -10)
    else
      exit 0
    fi
  else
    exit 0
  fi
fi

# Python test patterns
if [ "$EXT" = "py" ]; then
  for pattern in "$DIR/test_$NAME.py" "$DIR/${NAME}_test.py" "tests/test_$NAME.py"; do
    if [ -f "$pattern" ]; then
      TEST_FILE="$pattern"
      break
    fi
  done

  if [ -n "$TEST_FILE" ]; then
    OUTPUT=$(python -m pytest "$TEST_FILE" -x -q 2>&1 | tail -10)
  else
    exit 0
  fi
fi

# Go test patterns
if [ "$EXT" = "go" ]; then
  TEST_FILE="$DIR/${NAME}_test.go"
  if [ -f "$TEST_FILE" ]; then
    OUTPUT=$(go test "./$DIR/..." -count=1 -run "." 2>&1 | tail -10)
  else
    exit 0
  fi
fi

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "Tests failed for $(basename "$FILE_PATH"):" >&2
  echo "$OUTPUT" >&2
  exit 1  # Warning — don't block, just inform
fi

exit 0
