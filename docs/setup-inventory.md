---
title: Setup Inventory
nav_order: 13
parent: Advanced
---
# Setup Inventory (October 2026)

What the author's live `~/.claude` contains, and where each piece lives in this repo. Everything
mirrored here was scrubbed: employer, colleague and project names, internal hosts, chat IDs and
home paths are replaced with placeholders (`ParentCo`, `AcmeCo`, `a colleague`, `example.com`,
`~`). Expect to adapt names and paths before anything runs on your machine.

## Layers

| Layer | What runs | In this repo |
|---|---|---|
| Rules | `CLAUDE.md` plus five @-imported files, kept under 150 lines total | [`rules/`](../rules/) |
| Process | [Superpowers](superpowers.md) plugin as the default process layer | install from the marketplace |
| Token filter | [RTK](rtk.md), a Bash hook that trims command output | install from upstream |
| Guards | 70+ hook scripts, mostly recorder plus gate pairs | [`hooks/`](../hooks/), [Guard Hooks](guard-hooks.md) |
| Skills | about 60 user skills | [`skills/`](../skills/) |
| Agents | 9 role agents (architect, code-reviewer, critic, debugger, executor, planner, qa-tester, security-reviewer, verifier) | [`agents/`](../agents/) |
| Commands | `/q`, `/r`, `/paste-guard`, `/tribune` | [`commands/`](../commands/) |
| Second model | Codex plugin for reviews and rescue passes | [Multi-Model Orchestration](multi-model-orchestration.md) |
| Background | 13 launchd jobs | [`scripts/claude-ops/`](../scripts/claude-ops/), [Background Jobs](background-jobs.md) |

## Plugins enabled

| Plugin | Why |
|---|---|
| `superpowers@claude-plugins-official` | Brainstorm, plan, test first, debug systematically, verify before done |
| `codex@openai-codex` | Independent review lane and rescue passes from a different model |
| `security-guidance@claude-plugins-official` | Background security review of edits |
| `commit-commands@claude-plugins-official` | `/commit`, `/commit-push-pr`, `/clean_gone` |
| `typescript-lsp@claude-plugins-official` | Language server for TypeScript repos |
| `watch@claude-video` | `/watch <url>`: frames plus transcript so Claude can answer questions about a video |

Installed but switched off: `caveman`, `context7` (used as an MCP instead), `frontend-design`,
`pr-review-toolkit`, `skill-creator`, `vercel`, and a few others. Switched off because each
duplicated something the setup already enforces, or cost context every session for little use.

MCP servers: `context7` (current library docs), `shadcn` (real components), `granola` (meeting
notes), plus two personal ones. Claude in Chrome for browser work.

## Third-party skills (linked, not copied)

These are in daily use but belong to their authors. Install from upstream.

| Skill | Upstream |
|---|---|
| archify | [tt-a1i/archify](https://github.com/tt-a1i/archify) |
| hand-drawn-diagrams | [muthuishere/hand-drawn-diagrams](https://github.com/muthuishere/hand-drawn-diagrams) |
| notebooklm | [teng-lin/notebooklm-py](https://github.com/teng-lin/notebooklm-py) |
| ai-slop-cleaner | [Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) |
| impeccable | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) (a copy is vendored in `skills/impeccable`) |

## Left out on purpose

| Item | Why |
|---|---|
| Runtime state (logs, `state.json`, `.omc/`, handoffs, memory files, insight data snapshots) | Personal session data, not setup |
| Bot settings with chat IDs, `.mcp.json`, `settings.local.json`, launchd plists with a username | Identifiers; sanitised example plists are in `scripts/claude-ops/launchd/` instead |
| Two persona profiles of real people in `skills/bro/personas/` | They describe real people. `default.md` stays |
| Five work-bound skills: a team-chat blocker bot, a chat persona bot, an accelerator audit report, an internal newsletter builder, an expenses filer | Each is built around named colleagues, internal chats or an employer system; placeholders would leave nothing useful |
| Coin-rain sound files | Audio of unknown licence |
| `*.bak` and `*.pre-*` script backups | Superseded versions |

## Repo-only items

Some skills and hooks in this repo predate the current setup and are not in the author's live
config any more (for example `api-test`, `deploy`, `refactor`, `lint-check`, `ts-check`). They are
kept because they still work as starting points. Four of the older skills (`brainstorming`,
`writing-plans`, `executing-plans`, `verification-before-completion`) now ship inside
[Superpowers](superpowers.md); if you install the plugin you do not need the copies here.
