#!/bin/bash
# Pre-commit verification hook
# Blocks `git commit` when TypeScript type check fails.
# Directly addresses the "false done" problem: Claude claiming verification
# complete before tsc actually passes.
#
# Bypass for WIP: include [wip], [skip-verify], or "WIP" in commit message.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only act on `git commit` commands
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Allow bypass for WIP / intentional partial commits
case "$COMMAND" in
  *"[skip-verify]"*|*"[wip]"*|*"WIP"*|*"--amend"*) exit 0 ;;
esac

# Skip if not a TypeScript project
if [ ! -f tsconfig.json ]; then
  exit 0
fi

# Surface current branch (catch wrong-branch commits)
BRANCH=$(git branch --show-current 2>/dev/null)
echo "Committing to branch: $BRANCH" >&2

# Run tsc -b (CI parity) when project refs exist; else --noEmit
if grep -q '"references"' tsconfig.json 2>/dev/null; then
  OUTPUT=$(npx tsc -b 2>&1 | tail -30)
else
  OUTPUT=$(npx tsc --noEmit 2>&1 | tail -30)
fi
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "BLOCKED: TypeScript type check failed. Fix errors before committing." >&2
  echo "Bypass with [wip] or [skip-verify] in commit message if intentional." >&2
  echo "" >&2
  echo "$OUTPUT" >&2
  exit 2
fi

exit 0
