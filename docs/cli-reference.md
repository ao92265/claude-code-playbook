---
title: CLI Reference
nav_order: 4
---
# Claude Code CLI Reference

Exhaustive flag list for `claude`. Most matter only in CI/headless. Pin this when wiring GitHub Actions or building wrappers.

## Headless / Pipeline Flags

| Flag | What It Does |
|------|--------------|
| `-p "<prompt>"` | One-shot non-interactive run. Exits when done. |
| `--output-format json` | Machine-parseable response. Pair with `jq` in CI. |
| `--max-budget-usd 0.50` | Hard kill if spend exceeds this dollar amount. Use in CI. |
| `--max-turns N` | Kill the session after N model turns. Loop guard. |
| `--json-schema <path>` | Constrain output to a JSON schema. Validates before exit. |
| `--init-only` | Run all SessionStart hooks then exit. CI sanity check. |

## Session & Worktree

| Flag | What It Does |
|------|--------------|
| `--worktree <path>` | Run in a git worktree at the path. Auto-creates if missing. |
| `--fork-session` | Branch off the current session. Two parallel threads share the start, diverge at the fork. |
| `--continue` | Resume the most recent session in the cwd. |
| `--resume <id>` | Resume a specific session by id. `claude --list` to find ids. |

## Model & Cost

| Flag | What It Does |
|------|--------------|
| `--model <id>` | Pin a model: `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5`. |
| `--fallback-model <id>` | If the primary model is rate-limited, drop to this one. CI-only — silent in interactive mode. |
| `--effort low\|medium\|high` | Reasoning effort level. `low` is faster and cheaper, `high` for hard problems. |

## Settings & Permissions

| Flag | What It Does |
|------|--------------|
| `--setting-sources project,user` | Restrict which CLAUDE.md / settings.json layers load. Same syntax as the SDK's `settingSources`. |
| `--disable-slash-commands` | Hard-disable all slash commands. Lockdown mode for CI. |
| `--maintenance` | Run with all hooks/skills disabled. Use when something is broken and you need to debug from a clean slate. |
| `--dangerously-skip-permissions` | Auto-approve every tool call. CI-only; never in interactive terminals on shared machines. |

## Discovery

| Flag | What It Does |
|------|--------------|
| `--list` | List recent sessions in the cwd. |
| `--debug` | Verbose log to a file. Pair with the `debug-window.sh` hook concept (tail the log). |
| `--version` | Print version. |

## Settings.json Patterns Worth Knowing

These are not in most guides. All live in `.claude/settings.json` (project) or `~/.claude/settings.json` (user).

```jsonc
{
  // Replace the default spinner verbs with project-branded ones
  "spinnerVerbs": {
    "mode": "replace",
    "verbs": ["Reading", "Editing", "Reasoning", "Shipping"]
  },

  // Suppress Anthropic-default tips, inject your own
  "spinnerTipsOverride": {
    "excludeDefault": true,
    "tips": ["Run /clear before switching tasks.", "Check /context if Claude feels slow."]
  },

  // Redirect plan-mode output to a custom directory
  "plansDirectory": "./reports/plans",

  "env": {
    // Trigger /compact at 80% instead of the 92% default
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"
  },

  "hooks": {
    // Fires when env files change (matcher applies to file paths, not tool names)
    "FileChanged": [
      {
        "matcher": "\\.env(\\.local|\\.production)?$",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/env-rotate-warn.sh"}]
      }
    ],
    // Fires when a hook itself blocks
    "PermissionDenied": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/log-denied.sh"}]}],
    // Fires when /clear or session end happens with failing tests
    "StopFailure": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/notify-failed.sh"}]}]
  }
}
```

## Env Vars Worth Knowing

| Var | Effect |
|-----|--------|
| `CLAUDE_CODE_SUBAGENT_MODEL` | Global floor for subagent model. Overrides invocation-level `model:` field. |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | Auto-compact trigger threshold (1–99). |
| `ENABLE_TOOL_SEARCH` | `auto:N` — switch to MCP tool search at N+ tools loaded. |
| `CLAUDE_CODE_TASK_LIST_ID` | Share a task list across sessions. |
| `DISABLE_OMC` | Kill switch for the oh-my-claudecode plugin layer. |
| `OMC_SKIP_HOOKS` | Comma-separated list of hook names to skip. |

## See Also

- [Cheat Sheet](cheat-sheet.md) — interactive commands
- [Configuration](configuration.md) — full settings reference
- [GitHub Actions](github-actions.md) — CLI in CI
- [SDK vs CLI](sdk-vs-cli.md) — when to reach for each
