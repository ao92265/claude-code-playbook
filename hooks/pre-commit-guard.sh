#!/bin/bash
# Pre-commit guard: blocks commits containing console.log or debugger statements
# Hook point: PreToolUse (matcher: "Bash")
# Exit codes: 0=pass, 1=warn, 2=block

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check git commit commands
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Check staged files for debug statements
ISSUES=$(git diff --cached --name-only -- '*.ts' '*.tsx' '*.js' '*.jsx' 2>/dev/null | while read -r file; do
  [ -f "$file" ] && git show ":$file" | grep -n 'console\.log\|console\.debug\|debugger\b' | while read -r line; do
    echo "  $file:$line"
  done
done)

if [ -n "$ISSUES" ]; then
  echo "Debug statements found in staged files:" >&2
  echo "$ISSUES" >&2
  echo "Remove them before committing." >&2
  exit 2
fi

exit 0
