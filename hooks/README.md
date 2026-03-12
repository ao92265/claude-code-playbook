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
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

### 2. Register in settings.json

Add hook configurations to `~/.claude/settings.json`. Here's a complete example with all included hooks:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/session-start-check.sh",
            "timeout": 15,
            "statusMessage": "Checking environment..."
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/pre-commit-guard.sh",
            "timeout": 10,
            "statusMessage": "Checking for debug statements..."
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/env-guard.sh",
            "timeout": 10,
            "statusMessage": "Checking for secrets..."
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/ts-check.sh",
            "timeout": 30,
            "statusMessage": "Checking TypeScript types..."
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/format-check.sh",
            "timeout": 15,
            "statusMessage": "Checking formatting..."
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/build-check.sh",
            "timeout": 60,
            "statusMessage": "Running build check..."
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

Runs `tsc --noEmit` whenever a TypeScript file is edited. Catches type errors immediately.

| Property | Value |
|----------|-------|
| **Hook point** | `PostToolUse` |
| **Matcher** | `Edit\|Write` |
| **Catches** | TypeScript type errors after every edit |
| **Requires** | `tsconfig.json` in the project |

---

### pre-commit-guard.sh

Blocks commits that contain `console.log`, `console.debug`, or `debugger` statements.

| Property | Value |
|----------|-------|
| **Hook point** | `PreToolUse` |
| **Matcher** | `Bash` |
| **Catches** | Debug statements left in staged files |
| **Triggers on** | `git commit` commands only |

---

### format-check.sh

Checks if edited files pass Prettier formatting rules. Warns (exit 1) but doesn't block.

| Property | Value |
|----------|-------|
| **Hook point** | `PostToolUse` |
| **Matcher** | `Edit\|Write` |
| **Catches** | Formatting inconsistencies in .ts, .tsx, .js, .jsx, .json, .css, .md files |
| **Requires** | Prettier installed in the project (`node_modules/.bin/prettier`) |

---

### env-guard.sh

Prevents committing `.env` files or code containing secret patterns (API keys, passwords, private keys).

| Property | Value |
|----------|-------|
| **Hook point** | `PreToolUse` |
| **Matcher** | `Bash` |
| **Catches** | `.env` files staged for commit, hardcoded secrets in diffs |
| **Triggers on** | `git add` and `git commit` commands |

---

### build-check.sh

Runs a full TypeScript build with OOM prevention after editing `.ts`/`.tsx` files. Automatically escalates memory if the first attempt OOMs.

| Property | Value |
|----------|-------|
| **Hook point** | `PostToolUse` |
| **Matcher** | `Edit\|Write` |
| **Catches** | Build failures, OOM errors during compilation |
| **Requires** | `tsconfig.json` in the project |
| **Note** | Starts with 4GB heap, escalates to 8GB on OOM |

---

### session-start-check.sh

Validates the development environment when a new Claude Code session begins. Reports git status, port conflicts, Docker state, Node.js version, GitHub credentials, and .env presence.

| Property | Value |
|----------|-------|
| **Hook point** | `SessionStart` |
| **Matcher** | `""` (empty — matches all) |
| **Catches** | Port conflicts, missing credentials, Docker issues, missing .env |
| **Note** | Always exits 0 (informational only) |

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

**Tips:**
- Always handle missing fields gracefully (`// empty` in jq)
- Exit early for irrelevant file types to keep hooks fast
- Use `>&2` for error output (stdout is captured differently)
- Test manually: `echo '{"tool_input":{"file_path":"test.ts"}}' | ./your-hook.sh`
