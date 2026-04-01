#!/bin/bash
# Command firewall: blocks irreversible/dangerous shell commands
# Hook point: PreToolUse (matcher: "Bash")
# Exit codes: 0=pass, 2=block

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip if no command
[ -z "$CMD" ] && exit 0

# Strip quoted strings and heredocs so we don't match text inside commit messages etc.
STRIPPED=$(echo "$CMD" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" | sed '/<<.*EOF/,/EOF/d')

# Block irreversible/dangerous commands
if echo "$STRIPPED" | grep -qE '(rm -rf /|git reset --hard|git push --force|git push .* --force|DROP TABLE|TRUNCATE TABLE|git clean -fd)'; then
  echo "BLOCKED: '$CMD' — this command is irreversible. Propose a safer alternative." >&2
  exit 2
fi

exit 0
