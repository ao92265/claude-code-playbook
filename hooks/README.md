---
title: Hooks
parent: Resources
nav_order: 3
---
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
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/firewall.sh",
            "timeout": 5,
            "statusMessage": "Checking for dangerous commands..."
          }
        ]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/protect-paths.sh",
            "timeout": 5,
            "statusMessage": "Checking for protected files..."
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/secret-scanner.py",
            "timeout": 5,
            "statusMessage": "Scanning for secrets..."
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/tdd-gate.sh",
            "timeout": 5,
            "statusMessage": "Checking for tests..."
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/plan-gate.sh",
            "timeout": 5,
            "statusMessage": "Checking for active plan..."
          }
        ]
      },
      {
        "matcher": "Agent|Task",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/require-agent-model.sh",
            "timeout": 5,
            "statusMessage": "Checking subagent model..."
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

### firewall.sh

Blocks irreversible or dangerous shell commands before they execute. Catches `rm -rf /`, `git reset --hard`, `git push --force`, `DROP TABLE`, `TRUNCATE TABLE`, and `git clean -fd`.

| Property | Value |
|----------|-------|
| **Hook point** | `PreToolUse` |
| **Matcher** | `Bash` |
| **Catches** | Destructive shell commands that are hard or impossible to reverse |
| **Triggers on** | Any bash command matching dangerous patterns |

---

### protect-paths.sh

Prevents Claude from editing or writing to sensitive files (`.env`, lockfiles, Prisma schema) without explicit developer permission. Customize the `PROTECTED` array for your project.

| Property | Value |
|----------|-------|
| **Hook point** | `PreToolUse` |
| **Matcher** | `Edit\|Write` |
| **Catches** | Modifications to `.env*`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `prisma/schema.prisma` |
| **Customizable** | Edit the `PROTECTED` array to add/remove paths |

---

### require-agent-model.sh

Blocks `Agent`/`Task` tool calls that omit an explicit `model` field. Prevents subagents from silently inheriting the parent conversation model (usually Opus) and multiplying token spend. See [cost-guide.md → Smart Model Routing](../docs/cost-guide.md) for the full resolution order and rationale.

| Property | Value |
|----------|-------|
| **Hook point** | `PreToolUse` |
| **Matcher** | `Agent\|Task` |
| **Catches** | `Agent(...)` / `Task(...)` invocations missing `model: "haiku\|sonnet\|opus"` |
| **Requires** | `jq` on `PATH` (fails open if absent so it never bricks a session) |
| **Bypass** | Export `REQUIRE_AGENT_MODEL_DISABLED=1` for a one-off, or set `CLAUDE_CODE_SUBAGENT_MODEL` globally to pin a model and short-circuit the hook |

---

### secret-scanner.py

Regex-scans the content of every `Edit`/`Write`/`MultiEdit`/`NotebookEdit` for 30+ credential patterns (AWS, Anthropic, OpenAI, GitHub PATs, Stripe, Google, Slack, Supabase, Vercel, HuggingFace, Replicate, Groq, Databricks, Azure, DigitalOcean, Linear, Notion, JWT, private keys, DB connection strings with creds, hardcoded passwords). Wider net than `env-guard.sh`, which only catches secrets at `git add`/`git commit` time.

| Property | Value |
|----------|-------|
| **Hook point** | `PreToolUse` |
| **Matcher** | `Edit\|Write\|MultiEdit\|NotebookEdit` |
| **Catches** | Credential patterns being written into any file |
| **Requires** | Python 3 (stdlib only — no pip deps) |
| **Severity** | Critical/high → exit 2 (blocks). Medium → exit 1 (warns). |
| **Bypass** | Export `SECRET_SCANNER_DISABLED=1` |

---

### tdd-gate.sh

Warns when Claude edits a production source file that has no matching test file. Pairs with the [test-first skill](../skills/test-first/). Soft-default (warn-only); set `TDD_GATE_BLOCK=1` to make it block. Recognises TS, JS, Python, Go, Rust, Java, Kotlin, C#. Skips test files, fixtures, migrations, generated code, infra/config, and docs.

| Property | Value |
|----------|-------|
| **Hook point** | `PreToolUse` |
| **Matcher** | `Edit\|Write` |
| **Catches** | Source files without a co-located or `tests/`-located test file |
| **Requires** | `jq` |
| **Modes** | Warn (default, exit 1) or Block (`TDD_GATE_BLOCK=1`, exit 2) |
| **Bypass** | Export `TDD_GATE_DISABLED=1` |

---

### plan-gate.sh

Warns (never blocks) when Claude edits source code without a recent plan/spec on disk. Looks for any `*.spec.md`, `tasks/*.md`, `plans/*.md`, `.omc/plans/**/*.md`, `PLAN.md`, or `SPEC.md` modified within `PLAN_GATE_WINDOW_DAYS` (default 14). Encourages spec-first development without getting in the way of quick fixes.

| Property | Value |
|----------|-------|
| **Hook point** | `PreToolUse` |
| **Matcher** | `Edit\|Write` |
| **Catches** | Source edits with no plan/spec touched in the last N days |
| **Configurable** | `PLAN_GATE_WINDOW_DAYS=N` (default 14) |
| **Bypass** | Export `PLAN_GATE_DISABLED=1` |

---

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
