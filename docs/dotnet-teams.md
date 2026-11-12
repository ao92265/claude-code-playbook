---
title: .NET Teams
nav_order: 51
parent: Advanced
---
# Claude Code for .NET Teams

Three small changes that matter most on a .NET codebase: a build check after every C# edit, one shared instruction file, and guardrails for secrets and approvals.

Source: Mehdi Mohseni, ["Claude Code for .NET Developers"](https://medium.com/@mome.mohseni/claude-code-for-net-developers-a-practical-agentic-workflow-5e36f26187d9), Medium, 30 Oct 2026. The hook is adapted from it; the other two items are checked against the Claude Code docs below.

## 1. Build check after C# edits

[`hooks/dotnet-build.sh`](../hooks/dotnet-build.sh) is a `PostToolUse` hook on `Edit|Write`. It does nothing unless the edited file is a `.cs` or `.csproj`. When it is, it runs `dotnet build --no-restore -v q -nologo` and, on failure, sends back only the compiler error lines (`grep -E "error [A-Z]+[0-9]+" | sort -u | head -20`) on stderr with exit 2, so Claude sees the errors and nothing else.

The article matches the file name with a string pattern on the raw JSON. This version reads `tool_input.file_path` with `jq` instead, the same way [`build-check.sh`](../hooks/build-check.sh) does for TypeScript.

Wire it in `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/dotnet-build.sh" }
        ]
      }
    ]
  }
}
```

Copy the script to `.claude/hooks/dotnet-build.sh` and make it executable.

Notes:

- `--no-restore` assumes packages are already restored. Run `dotnet restore` once at session start or after changing package references.
- With one solution in the project root, `dotnet build` finds it. With several, set `DOTNET_BUILD_TARGET` to the `.sln` or `.csproj` to build.
- On large solutions a full build after every edit is slow. Point `DOTNET_BUILD_TARGET` at the nearest project, or leave the build to a `Stop` hook and run tests there (see [Guard Hooks](guard-hooks.md): keep `PostToolUse` fast, push slow work to `Stop`).
- No dotnet SDK on the path, or no solution in the project root: the first exits 0 silently; the second fails with `error MSB1003` and exit 2, which is a handled failure, not a crash.

## 2. One instruction file for every tool

Keep cross-tool rules in `AGENTS.md` and put this in `CLAUDE.md`:

```markdown
@AGENTS.md
```

Confirmed in the [memory docs](https://code.claude.com/docs/en/memory.md): Claude Code reads `AGENTS.md` on its own only when there is no `CLAUDE.md` or `CLAUDE.local.md` in the working directory or above it. If both exist it reads `CLAUDE.md` only, so the import line is what brings `AGENTS.md` in. Put Claude-specific rules below the import.

## 3. Team guardrails

**Approval mode.** Confirmed in the [permission modes docs](https://code.claude.com/docs/en/permission-modes.md): from v2.1.283, auto mode is the built-in starting mode for interactive terminal and VS Code sessions. A team that wants a human to approve each action sets the default in shared settings:

```json
{
  "permissions": {
    "defaultMode": "default"
  }
}
```

`"manual"` is accepted as an alias for `"default"` (the mode is called Manual in the CLI).

**Secrets.** Deny rules block in every mode, including `bypassPermissions` (same page). Add `Read` deny rules for environment files and .NET config files that carry connection strings:

```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./**/appsettings.*.json)"
    ]
  }
}
```

Plain `appsettings.json` is usually safe to leave readable, since it should hold no secrets; add `Read(./**/appsettings.json)` if yours does. Claude Code applies `Read` deny rules on a best-effort basis to Grep, Glob and `@file` mentions, so pair this with [`protect-paths`](guard-hooks.md) and keep real secrets in user secrets or a vault. See [Permissions](permissions.md) for rule syntax.
