---
title: Complete Guide
nav_order: 5
---
# Claude Code: The Complete Guide

This guide used to be a single 600-line page that covered every topic at a shallow depth. It has been split into focused pages, each with more room to go deep than the mega-guide ever had. Use the map below to jump to what you need.

The core session workflow stays on this page — the request/verify rhythm, context management, and reverse prompting — because it underpins everything else in the playbook. The Recommended CLAUDE.md Template is kept here too, as a ready-to-copy starting point.

## Where Each Topic Now Lives

| Topic | Page |
|:------|:-----|
| Setup and installation | [Getting Started](getting-started.md) |
| Configuration and hooks | [Configuration](configuration.md) |
| Sessions and context management | Kept on this page, below |
| Reverse prompting | Kept on this page, below |
| Plugins | [Skills Ecosystem](skills-ecosystem.md) |
| MCP servers | [MCP Servers](mcp-servers.md) |
| BMAD and autonomous development | [BMad Autonomous Development](bmad.md) |
| OMC session and execution modes | [Multi-Model Orchestration](multi-model-orchestration.md) |
| Agent teams and worktrees | [Agent Teams](agent-teams.md) |
| Slash commands and command reference | [CLI Reference](cli-reference.md) |
| Troubleshooting | [Troubleshooting](troubleshooting.md) |
| Case study and metrics | [Case Studies](case-studies.md) |
| Lessons from production | [Case Studies](case-studies.md) |
| Recommended CLAUDE.md template | Kept on this page, below |

---

## Core Workflow Principles

### Request, Implement, Verify, Close

The fundamental rhythm:

1. **Request**: Describe the feature or fix. Include context — relevant code snippets, error messages, or test cases.
2. **Implement**: Claude reads your code, explores related files, and delivers a solution. You watch the implementation as it happens.
3. **Verify**: Run tests, build, deploy to staging. Do not assume the implementation is correct from code inspection alone.
4. **Close**: Once verified, the session ends. New requests start fresh in a new session.

This is not iterative refinement. Each step has a clear boundary. Violating the boundary — saying "well, almost, let me tweak this" — turns a 5-minute session into a 90-minute slog.

### Separate Planning from Execution

Planning is exploratory. You and Claude discuss, disagree, sketch architecture, and settle on an approach. Execution is focused. Once you agree on the plan, close the session. In a new session, say: "Implement the design from our previous session" and point to the notes.

Why separate? Because planning context pollutes implementation focus. If Claude must remember three rejected approaches while writing code, it will second-guess itself and produce defensive, over-engineered implementations.

### Use CLAUDE.md, Not the Chat

CLAUDE.md is a Markdown file in your project root that Claude reads automatically at the start of every session. It contains:

- Coding standards (lint config, type rules, naming conventions)
- Architecture decisions (why we use Service layer, why not Redux, etc.)
- Patterns to follow (how to scaffold a new module, test setup, database migrations)
- Safety rules (never commit directly to main, always run the build, etc.)

Do not repeat these rules in the chat. Write them once in CLAUDE.md. Every session Claude reads CLAUDE.md automatically. This saves 10-20 minutes per session.

### Context Window Management

Claude's context window is finite. A typical session uses 50-80% of available context for the conversation. The remaining capacity holds your code, CLAUDE.md, and tool outputs. Manage it:

- Separate tasks into separate sessions. Do not handle three unrelated bugs in one session.
- Read CLAUDE.md before starting. It describes your patterns once, consuming tokens upfront but saving them on every instruction in the chat.
- Use `/mcp` strategically. MCP servers add context weight. Disable servers you're not using during a session (`/mcp` to see token costs).
- Upload code snippets, not entire files. If you paste a 500-line file to show one bug, extract just the relevant 20 lines.

### Context Pollution

Context pollution is what happens when your conversation accumulates irrelevant or conflicting information — failed approaches, abandoned ideas, debug output — that degrades Claude's performance. It is the single biggest cause of Claude "getting dumber" during a session.

Strategies to prevent it:

- Separate planning from execution (see *Separate Planning from Execution*, above). Planning context is exploratory and pollutes implementation focus.
- Use `/clear` when switching tasks. Do not carry debugging context into a new feature.
- Offload research to subagents — they have their own context window and die when done.
- Move stable rules into CLAUDE.md and skills rather than restating them each session.
- Run `/context` regularly to see what is consuming tokens. Disable MCP servers you are not using (`/mcp`).
- Use `/compact` when context exceeds 50% but the session is still productive. Start fresh if above 80%.

Rule of thumb: if Claude starts giving generic answers or forgetting earlier instructions, your context is polluted. Start a new session.

### Reverse Prompting

Instead of giving Claude detailed specifications upfront, ask Claude to interview you. This is reverse prompting — flipping the conversation so Claude asks the questions and you provide the domain knowledge.

Practical applications:

- "Ask me 20 clarifying questions about how this feature should work before you start." — Claude's questions reveal edge cases you hadn't considered.
- "You are the architect. Interview me about the requirements for this module." — produces better specs than writing them yourself.
- "What questions would a QA engineer ask about this implementation?" — surfaces test scenarios.
- "Review what you know about our codebase and tell me what's unclear." — identifies gaps in CLAUDE.md.

Reverse prompting works because Claude has seen millions of software projects and knows what questions to ask. Your domain knowledge combined with Claude's pattern recognition produces better outcomes than either alone.

### Rewind

The `/rewind` command undoes your last message without losing the session. Use it to correct mistakes:

```
$ claude
/rewind   # Your last message is deleted, context preserved
          # Retype a corrected request
```

This is faster than abandoning the session and starting over. But do not use `/rewind` to iterate on Claude's response. If the implementation is wrong, that is a sign the specification was unclear. Close the session, clarify the spec in a planning session, and start fresh.

### Bug Fixing Workflow

Bugs discovered in production require a specific workflow:

1. **Isolate**: Create the smallest failing test case that reproduces the bug.
2. **Request**: Paste the test case and the error into Claude with "This test fails. Make it pass."
3. **Verify in staging**: Do not merge until you've run the test in staging and it passes.

The isolation step is critical. A bug report like "Users can't upload files" is useless. Narrow it down: "PNG files over 5MB fail with status 413 in the multipart handler."

---

## Recommended CLAUDE.md Template

Based on the patterns in this playbook, every project should start with a CLAUDE.md that includes these sections at minimum:

```markdown
## Token Efficiency
Use low reasoning effort by default. Only escalate when stuck on a genuinely hard
debugging or architectural problem. When spawning sub-agents: use Sonnet for
implementation, Haiku for simple tasks, reserve Opus for complex decisions.

## Change Philosophy
Make the smallest change that works. Follow existing patterns. Don't refactor
surrounding code or add abstractions beyond what was asked.

## Verification
Always verify work end-to-end before reporting success. Run the actual test, build,
or workflow. Never assume correctness from code analysis.

## Communication Rules
Never assume the user's environment is wrong. Always check the actual state of files,
configs, and services.

## Git & GitHub Rules
Do not push code without explicit permission. Do not perform destructive operations
without asking first.
```

### Hook Recipes to Adopt

For any TypeScript project, install at minimum: auto-format, build-watcher, pre-commit-gate, and migration-guard. See [Getting Started](getting-started.md) for the hook setup walkthrough.

### Skills Worth Creating First

Custom skills give Claude deep domain knowledge about your specific project. Prioritize:

1. **Module scaffolding skill** — Generates new backend modules (service + controller + DTO + spec) or frontend pages (component + route + API hook) following your project's exact patterns. Eliminates 80% of boilerplate errors.

2. **Database operations skill** — Understands your schema and generates correct migrations, seed data, and relation handling. Especially valuable for SQL Server projects where Prisma has edge cases.

3. **Testing patterns skill** — Knows your test setup (Jest config, mock patterns, fixture locations) and generates tests that actually pass on first run.

4. **Legacy migration mapping skill** — Maps legacy module names, function signatures, and data access patterns to their modern equivalents. The highest-value skill for accelerating any migration project.

Skills are YAML frontmatter + markdown body files stored in `.claude/skills/`. See the [Skills Ecosystem](skills-ecosystem.md) guide for the creation format.

As a general principle, review CLAUDE.md after every major model release. Instructions that compensate for model weaknesses often become unnecessary — and leftover instructions waste context tokens.
