---
title: .NET Teams
nav_order: 51
parent: Advanced
---
# Claude Code for .NET Teams

Three small changes that matter most on a .NET codebase: a build check after every C# edit, one shared instruction file, and guardrails for secrets and approvals.

Source: Mehdi Mohseni, ["Claude Code for .NET Developers"](https://medium.com/@mome.mohseni/claude-code-for-net-developers-a-practical-agentic-workflow-5e36f26187d9), Medium, 30 Oct 2026. The hook is adapted from it; the other two items are checked against the Claude Code docs below.

## 1. Build check after C# edits

[`hooks/dotnet-build.sh`](../hooks/dotnet-build.sh) is a `PostToolUse` hook on `Edit|Write`. It does nothing unless the edited file is a `.cs` file. A `.cs` edit triggers a build, and MSBuild runs code from many files it evaluates (project files, `*.user`, `Directory.Build.*`, `.props`, `.targets`, generated files under `obj/`, wildcard import folders), so the build hook must be installed together with its guard, [`hooks/dotnet-msbuild-guard.sh`](../hooks/dotnet-msbuild-guard.sh). The guard is a `PreToolUse` hook on `Edit|Write|MultiEdit|NotebookEdit` and works as an allowlist, not a denylist. It asks the developer (it does not deny) unless all of these hold: the path is ASCII only (backslashes are read as `/`), it resolves, following symlinks, to inside `CLAUDE_PROJECT_DIR`, no path component is `.git`, `obj`, `bin`, `.claude`, `.nuget` or contains `msbuild`, `importbefore` or `importafter`, and the extension is one of `.cs .md .razor .cshtml .css .scss .js .ts .tsx .html .txt` or `.json` other than `global.json`. If `jq` or `python3` is missing it asks. It always exits 0; the decision is the `permissionDecision: "ask"` JSON on stdout.

The build hook keeps a second layer. It needs `DOTNET_BUILD_TARGET` set to the `.sln` or `.csproj` to build and passes it to `dotnet build` explicitly, so auto-detection cannot pick up a new project; with it unset the build is skipped with a one-line note. It also skips the build (exit 0, note on stderr) when `git status --porcelain=v1 -z --untracked-files=all` lists any new or changed file that is not `.cs` or `.md`, a collapsed directory entry or a dirty submodule, when the project is not a git repo, when a `.props` or `.targets` file under `obj/` is newer than `obj/project.assets.json`, or when any `*.user` file is newer than it. On a `.cs` edit with all that clear it runs `dotnet build "$DOTNET_BUILD_TARGET" --no-restore -v q -nologo` plus four `-p:ImportUserLocationsByWildcard{Before,After}MicrosoftCommon{Props,Targets}=false` properties that switch off per-user ImportBefore/ImportAfter folders and, on failure, sends back only the compiler error lines (`grep -E "error [A-Z]+[0-9]+" | sort -u | head -20`) on stderr with exit 2, so Claude sees the errors and nothing else.

### What these hooks do not cover

- Files written through Bash. Keep Bash on ask in repos using these hooks.
- `Directory.Build.*` files in parent directories outside the repo.
- Build-time code in the repo itself: Roslyn analyzers, source generators and custom MSBuild tasks run from `.cs` code. Any build of such a repo runs code Claude edited.
- Scripts the build runs. A project can call `package.json` scripts or JavaScript through an `Exec` target or an `.esproj`. The guard allows `.js`, `.ts` and `.json` edits silently, and the build hook skips only on git changes, so a manual build still runs that code.
- Bypass-permissions mode, where "ask" prompts are not shown.
- Windows. The scripts are tested on macOS only.

For the strongest setup, run the build in a sandbox with no network and no secrets.

The article matches the file name with a string pattern on the raw JSON. This version reads `tool_input.file_path` with `jq` instead, the same way [`build-check.sh`](../hooks/build-check.sh) does for TypeScript.

Wire both in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/dotnet-msbuild-guard.sh", "timeout": 10 }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/dotnet-build.sh", "timeout": 300 }
        ]
      }
    ]
  }
}
```

Copy both scripts to `.claude/hooks/` and make them executable. Set `DOTNET_BUILD_TARGET` in the `env` block of `.claude/settings.json`.

Notes:

- Parallel edits can start two builds on the same `obj/` folder, and file-lock errors may come back as build errors. Re-run the build before trusting them.
- `--no-restore` assumes packages are already restored. Run `dotnet restore` once at session start or after changing package references.
- `DOTNET_BUILD_TARGET` is required (the `.sln` or `.csproj` to build); there is no auto-detection.
- On large solutions a full build after every edit is slow. Point `DOTNET_BUILD_TARGET` at the nearest project, or leave the build to a `Stop` hook and run tests there (see [Guard Hooks](guard-hooks.md): keep `PostToolUse` fast, push slow work to `Stop`).
- No dotnet SDK on the path, or `DOTNET_BUILD_TARGET` unset: the hook exits 0 (with a note when unset). If the build fails with no coded compiler error, the last 20 lines of build output go to stderr with exit 2.

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
