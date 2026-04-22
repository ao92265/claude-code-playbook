#!/bin/bash
# audit-log.sh — append every user prompt to a compliance log.
#
# Wire as UserPromptSubmit hook in .claude/settings.json:
#   {
#     "hooks": {
#       "UserPromptSubmit": [
#         { "matcher": ".*",
#           "hooks": [{ "type": "command",
#                       "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/audit-log.sh" }] }
#       ]
#     }
#   }
#
# Pattern adapted from awslabs/aidlc-workflows (aidlc-docs/audit.md).
# See docs/audit-log-hook.md for context.

set -u

AUDIT_DIR="${CLAUDE_AUDIT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}/.claude/audit}"
AUDIT_FILE="${AUDIT_DIR}/prompts.md"

mkdir -p "$AUDIT_DIR"

PAYLOAD="$(cat)"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if command -v jq >/dev/null 2>&1; then
  SESSION_ID="$(printf '%s' "$PAYLOAD" | jq -r '.session_id // "unknown"')"
  CWD="$(printf '%s' "$PAYLOAD" | jq -r '.cwd // "unknown"')"
  PROMPT="$(printf '%s' "$PAYLOAD" | jq -r '.prompt // ""')"
else
  SESSION_ID="jq-missing"
  CWD="$PWD"
  PROMPT="$PAYLOAD"
fi

{
  printf '## Prompt\n'
  printf '**Timestamp**: %s\n' "$TIMESTAMP"
  printf '**Session**: `%s`\n' "$SESSION_ID"
  printf '**Cwd**: `%s`\n' "$CWD"
  printf '**User Input**:\n\n```\n%s\n```\n\n---\n\n' "$PROMPT"
} >> "$AUDIT_FILE"

exit 0
