# Claude Code Hooks

Hooks are shell scripts that run automatically at defined points during a Claude Code session. They enforce consistency without requiring manual review.

## How Hooks Work

Claude Code supports these hook points:

| Hook Point | When It Runs |
|------------|-------------|
| `PreToolUse` | Before Claude uses a tool (Edit, Write, Bash, etc.) |
| `PostToolUse` | After Claude uses a tool |
| `Notification` | When Claude sends a notification |
| `Stop` | When Claude finishes a response |
| `SessionStart` | When a new session begins |

## Setting Up Hooks

### 1. Create the hook script

Place your hook scripts in `~/.claude/hooks/` (global) or `.claude/hooks/` (project-local):

```bash
mkdir -p ~/.claude/hooks
cp ts-check.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/ts-check.sh
```

### 2. Register in settings.json

Add the hook configuration to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/ts-check.sh",
            "timeout": 30,
            "statusMessage": "Checking TypeScript types..."
          }
        ]
      }
    ]
  }
}
```

### Configuration Options

| Field | Description |
|-------|-------------|
| `matcher` | Regex pattern matching tool names (e.g., `"Edit"`, `"Edit\|Write"`, `""` for all) |
| `type` | Always `"command"` |
| `command` | Path to the hook script |
| `timeout` | Maximum execution time in seconds |
| `statusMessage` | Message shown in the spinner while the hook runs |
| `async` | If `true`, hook runs without blocking (fire-and-forget) |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success — continue normally |
| 1 | Warning — show output but continue |
| 2 | Error — block the operation and show output |

## Included Hooks

### ts-check.sh

A PostToolUse hook that automatically runs `tsc --noEmit` whenever a `.ts` or `.tsx` file is edited. Catches type errors immediately rather than waiting for a build step.

**Matcher**: `Edit|Write`
**When to use**: Any TypeScript project with a `tsconfig.json`

## Creating Custom Hooks

Hooks receive JSON on stdin with the tool input. Parse it with `jq`:

```bash
#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Your logic here
if some_check_fails "$FILE_PATH"; then
  echo "Error: check failed for $FILE_PATH" >&2
  exit 2
fi

exit 0
```
