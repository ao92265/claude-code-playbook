# Claude Code: The Complete Power User Guide

Skills, Plugins, MCP Servers, Agents, and Orchestration

---

## Contents

1. [What Is Claude Code?](#1-what-is-claude-code)
2. [Core Workflow Principles](#2-core-workflow-principles)
3. [Setup and Configuration](#3-setup-and-configuration)
4. [Plugins](#4-plugins)
5. [MCP Servers](#5-mcp-servers)
6. [Advanced Features](#6-advanced-features)
7. [BMAD — Multi-Agent Orchestration](#7-bmad--multi-agent-orchestration)
8. [OMC — Advanced Session Management](#8-omc--advanced-session-management)
9. [Slash Commands](#9-slash-commands)
10. [Commands Reference](#10-commands-reference)
11. [Troubleshooting](#11-troubleshooting)
12. [Case Study](#12-case-study)
13. [Lessons from Production](#13-lessons-from-production)
14. [Recommended CLAUDE.md Template](#14-recommended-claudemd-template)

---

## 1. What Is Claude Code?

Claude Code is an IDE-integrated command-line tool for using Claude with your codebase. It reads your project, understands your patterns, and works in session-oriented mode: you request something, Claude delivers a complete implementation, you verify it, and the session closes.

This guide documents patterns discovered through production use across multiple TypeScript projects. It is written as an operational manual for experienced developers. It assumes familiarity with Unix shells, Git workflows, TypeScript, and why testing matters.

## 2. Core Workflow Principles

### 2.1 Request, Implement, Verify, Close

The fundamental rhythm:

1. **Request**: Describe the feature or fix. Include context — relevant code snippets, error messages, or test cases.
2. **Implement**: Claude reads your code, explores related files, and delivers a solution. You watch the implementation as it happens.
3. **Verify**: Run tests, build, deploy to staging. Do not assume the implementation is correct from code inspection alone.
4. **Close**: Once verified, the session ends. New requests start fresh in a new session.

This is not iterative refinement. Each step has a clear boundary. Violating the boundary — saying "well, almost, let me tweak this" — turns a 5-minute session into a 90-minute slog.

### 2.2 Separate Planning from Execution

Planning is exploratory. You and Claude discuss, disagree, sketch architecture, and settle on an approach. Execution is focused. Once you agree on the plan, close the session. In a new session, say: "Implement the design from our previous session" and point to the notes.

Why separate? Because planning context pollutes implementation focus. If Claude must remember three rejected approaches while writing code, it will second-guess itself and produce defensive, over-engineered implementations.

### 2.3 Use CLAUDE.md, Not the Chat

CLAUDE.md is a Markdown file in your project root that Claude reads automatically at the start of every session. It contains:

- Coding standards (lint config, type rules, naming conventions)
- Architecture decisions (why we use Service layer, why not Redux, etc.)
- Patterns to follow (how to scaffold a new module, test setup, database migrations)
- Safety rules (never commit directly to main, always run the build, etc.)

Do not repeat these rules in the chat. Write them once in CLAUDE.md. Every session Claude reads CLAUDE.md automatically. This saves 10-20 minutes per session.

### 2.4 Context Window Management

Claude's context window is finite. A typical session uses 50-80% of available context for the conversation. The remaining capacity holds your code, CLAUDE.md, and tool outputs. Manage it:

- Separate tasks into separate sessions. Do not handle three unrelated bugs in one session.
- Read CLAUDE.md before starting. It describes your patterns once, consuming tokens upfront but saving them on every instruction in the chat.
- Use `/mcp` strategically. MCP servers add context weight. Disable servers you're not using during a session (`/mcp` to see token costs).
- Upload code snippets, not entire files. If you paste a 500-line file to show one bug, extract just the relevant 20 lines.

### 2.5 Context Pollution

Context pollution is what happens when your conversation accumulates irrelevant or conflicting information — failed approaches, abandoned ideas, debug output — that degrades Claude's performance. It is the single biggest cause of Claude "getting dumber" during a session.

Strategies to prevent it:

- Separate planning from execution (Section 2.2). Planning context is exploratory and pollutes implementation focus.
- Use `/clear` when switching tasks. Do not carry debugging context into a new feature.
- Offload research to subagents — they have their own context window and die when done.
- Move stable rules into CLAUDE.md and skills rather than restating them each session.
- Run `/context` regularly to see what is consuming tokens. Disable MCP servers you are not using (`/mcp`).
- Use `/compact` when context exceeds 50% but the session is still productive. Start fresh if above 80%.

Rule of thumb: if Claude starts giving generic answers or forgetting earlier instructions, your context is polluted. Start a new session.

### 2.6 Reverse Prompting

Instead of giving Claude detailed specifications upfront, ask Claude to interview you. This is reverse prompting — flipping the conversation so Claude asks the questions and you provide the domain knowledge.

Practical applications:

- "Ask me 20 clarifying questions about how this feature should work before you start." — Claude's questions reveal edge cases you hadn't considered.
- "You are the architect. Interview me about the requirements for this module." — produces better specs than writing them yourself.
- "What questions would a QA engineer ask about this implementation?" — surfaces test scenarios.
- "Review what you know about our codebase and tell me what's unclear." — identifies gaps in CLAUDE.md.

Reverse prompting works because Claude has seen millions of software projects and knows what questions to ask. Your domain knowledge combined with Claude's pattern recognition produces better outcomes than either alone.

### 2.7 Rewind

The `/rewind` command undoes your last message without losing the session. Use it to correct mistakes:

```
$ claude
/rewind   # Your last message is deleted, context preserved
          # Retype a corrected request
```

This is faster than abandoning the session and starting over. But do not use `/rewind` to iterate on Claude's response. If the implementation is wrong, that is a sign the specification was unclear. Close the session, clarify the spec in a planning session, and start fresh.

### 2.8 Bug Fixing Workflow

Bugs discovered in production require a specific workflow:

1. **Isolate**: Create the smallest failing test case that reproduces the bug.
2. **Request**: Paste the test case and the error into Claude with "This test fails. Make it pass."
3. **Verify in staging**: Do not merge until you've run the test in staging and it passes.

The isolation step is critical. A bug report like "Users can't upload files" is useless. Narrow it down: "PNG files over 5MB fail with status 413 in the multipart handler."

## 3. Setup and Configuration

### 3.1 Installation

Install Claude Code from https://github.com/anthropics/claude-code/releases (or `brew install claude-code` on macOS). Authenticate with your Anthropic API key:

```bash
$ claude login
# Paste your API key when prompted
# Stored securely in ~/.claude/auth.json
```

### 3.2 Terminal Setup

Run Claude Code in a terminal where you can see output. Recommended: Ghostty (fast, Unicode support, works on Linux and macOS). On Windows, use PowerShell or Windows Terminal.

Set `EDITOR` to your preferred editor for git messages and diffs:

```bash
export EDITOR=vim  # or code, nano, emacs
```

### 3.3 Hooks

Hooks are shell scripts that run at defined points: before/after commits, before/after builds, on file changes. They enforce consistency without requiring manual review.

| Hook | Purpose |
|------|---------|
| pre-commit | Blocks commits if ESLint fails or TypeScript has errors |
| post-commit | Updates documentation or changelogs automatically |
| pre-push | Runs the full test suite before pushing to remote |
| build-watcher | Watches for file changes and rebuilds automatically |
| migration-guard | Prevents merging migration changes with other code |
| format-enforce | Forces Prettier format before commit |
| deployment-guard | Blocks deployments if staging tests fail |
| prisma-auto-generate | Automatically regenerates the Prisma client after schema changes |

To set up hooks, create shell scripts in `.claude/hooks/` and register them in `.claude/settings.json`. Or just tell Claude: "Set up a pre-commit hook that blocks console.logs and TypeScript errors." Claude will create the hook script and update the settings for you.

### 3.4 Skills

Skills are custom slash commands that teach Claude domain knowledge. They live in `.claude/skills/` as Markdown files with YAML frontmatter.

Example: a skill named "Scaffold Backend Module" that generates a complete service + controller + DTO + test following your project's structure. Instead of repeating the pattern, you tell Claude: `/scaffold-backend-module CreateUser`

Create skills for:

- Module scaffolding (backend service, frontend component)
- Database operations (migrations, seeds, schema updates)
- Testing patterns (mocking, fixture setup, test data)
- Legacy migration (mapping old code to new structure)

## 4. Plugins

### 4.1 What Are Plugins

Plugins bundle skills, MCP servers, agents, hooks, and slash commands into one installable unit. Over 9,000 exist in the official marketplace as of early 2026.

### 4.2 Installing Plugins

List available plugins:

```bash
$ claude /plugin list
```

Install a plugin:

```bash
$ claude /plugin install Context7
```

You can also just ask Claude in plain English: "Install the Context7 plugin" or "Add the BMAD plugin to this project." Claude will find and install it.

### 4.3 Recommended Plugins

Start with these core plugins:

- **Context7**: AI-powered documentation and code search.
- **BMAD**: Multi-agent orchestration (see Section 7).
- **OMC**: Advanced session management (see Section 8).
- **DevTools**: Debugging, profiling, performance analysis.

## 5. MCP Servers

### 5.1 What Are MCP Servers

MCP servers connect Claude to external systems — databases, APIs, browsers, SaaS tools. They expose tools Claude can call to take real-world actions. MCP is now an open standard under the Linux Foundation.

### 5.2 Essential MCP Servers

| Server | Purpose |
|--------|---------|
| Filesystem | Read/write files, run Git commands, check build status |
| Postgres/MySQL | Execute queries, inspect schema, generate migrations |
| Browser | Navigate URLs, execute JavaScript, fill forms, take screenshots |
| Slack | Send messages, check channel history, post threads |
| GitHub CLI (gh) | Preferred over GitHub MCP. Lower token cost, better debugging, native composability with bash |

**GitHub CLI vs GitHub MCP**: Use the GitHub CLI (`gh`) rather than the GitHub MCP server. The CLI consumes less context, is easier to debug, and Claude handles it naturally. Add "Use the gh CLI for GitHub operations, not MCP" to your CLAUDE.md. Install gh: `brew install gh` (macOS), `winget install GitHub.cli` (Windows), or `sudo apt install gh` (Linux).

## 6. Advanced Features

### 6.1 Agent Teams

Spawn multiple Claude instances working in parallel on independent tasks. Use agent teams for:

- Code review (three parallel agents review for logic, security, and performance)
- Testing (one agent writes tests while another implements features)
- Parallel bug fixes (separate agents handle different high-priority bugs)

Syntax: request spawning within a session with `/spawn`. See Section 8 for details.

### 6.2 Worktrees

Worktrees are isolated Git branches. Each worktree is a full, independent copy of your codebase on a different branch. Use them when you need to:

- Work on a feature without stashing your current changes
- Test multiple approaches in parallel
- Allow agent teams to work simultaneously without conflicts

Syntax: `/worktree create feature-name`

## 7. BMAD — Multi-Agent Orchestration

### 7.1 What Is BMAD

BMAD is a plugin that allows you to spawn multiple specialized agents — the Architect, the Developer, the QA Engineer, the Security Auditor, and the Product Manager — who work together on a single request. Each agent has domain expertise and a defined perspective.

### 7.2 When to Use BMAD

Use BMAD when:

- Designing a complex system (let the Architect and Security Auditor stress-test the design)
- Reviewing code for production readiness (QA, Security, and Dev agents catch issues together)
- Planning sprints or releases (PM, Dev, and Architect align on scope and feasibility)
- Debugging production incidents (multiple perspectives speed root-cause analysis)

### 7.3 Standard BMAD Agents

| Agent | Role |
|-------|------|
| Architect | Evaluates design, raises scalability and maintainability concerns |
| Developer | Owns implementation, raises edge cases and testing concerns |
| QA Engineer | Writes test cases, identifies coverage gaps |
| Security Auditor | Flags security risks, compliance issues, injection vulnerabilities |
| Product Manager | Raises scope, timeline, and user impact concerns |

### 7.4 Party Mode

To start Party Mode, use `/bmad-party-mode` or just tell Claude "start a party mode session." The BMad Master agent activates and orchestrates other agents. As you type messages, relevant agents respond in character.

Party Mode is most valuable during:

- **Analysis phase** — multiple perspectives on problem definition prevent tunnel vision
- **Architecture reviews** — Architect + Security Auditor + Developer catch issues early
- **Sprint retrospectives** — QA, Dev, and SM agents identify process improvements

### 7.5 BMAD Modules

| Module | Purpose |
|--------|---------|
| BMM (BMad Method Module) | Core Agile suite for software development |
| BMB (BMad Builder) | Framework for creating custom AI agents and extensions |
| CIS (Creative Intelligence Suite) | Innovation, design thinking, and brainstorming |
| BMVCS (Version Control System) | Git workflow automation and version control |
| BMGD (BMad Game Dev Studio) | Specialized module for game development |

### 7.6 BMAD Commands

**Agent activation:**

| Command | What It Does |
|---------|-------------|
| `/bmad:init` | Initialize BMAD in the current project |
| `/bmad-help` | Get guidance on what to do next |
| `/bmad-architect` | Activate the Architect |
| `/bmad-dev` | Activate the Developer agent |
| `/bmad-pm` | Activate the Product Manager |
| `/bmad-party-mode` | Activate Party Mode for multi-agent collaboration |

**Workflow commands:**

| Command | Phase |
|---------|-------|
| `/bmad-bmm-create-product-brief` | Analysis — Create initial product brief |
| `/bmad-bmm-create-prd` | Planning — Generate Product Requirements Document |
| `/bmad-bmm-create-architecture` | Solutioning — Design system architecture |
| `/bmad-bmm-create-epics-and-stories` | Solutioning — Break down into implementable stories |
| `/bmad-bmm-sprint-planning` | Implementation — Plan the sprint |
| `/bmad-bmm-dev-story` | Implementation — Develop a single story |
| `/bmad-bmm-code-review` | Implementation — Review completed work |

**Review commands:**

| Command | Purpose |
|---------|---------|
| `/bmad-review-adversarial-general` | Stress-test plans and designs |
| `/bmad-review-edge-case-hunter` | Find edge cases and failure modes |
| `/bmad-bmm-qa-generate-e2e-tests` | Generate end-to-end test suites from stories |

### 7.7 Installing BMAD

BMAD is available as a Claude plugin. Install it from the plugin marketplace and activate any of the commands above to get started.

## 8. OMC — Advanced Session Management

### 8.1 What Is OMC

OMC (oh-my-claudecode) is a plugin that provides advanced session tools: spawning parallel agents, managing context, running distributed workflows, and debugging Claude's decision-making.

### 8.2 Execution Modes

| Mode | Description |
|------|-------------|
| Autopilot | Flagship mode. Describe a goal, OMC handles the full lifecycle: planning, parallel execution, testing, and self-correction |
| Ultrawork | Maximum parallelism with up to 5 concurrent worker agents. 3-5x faster than sequential |
| Swarm | Coordinated agents pulling from a shared task pool. Prevents duplicate work |
| Pipeline | Sequential agent chains with preset workflows for review, implement, and debug |
| Ecomode | Token-efficient parallel execution with smart model routing. 30-50% token savings |
| Ralph | Persistence mode — keeps working until the Architect agent verifies the goal is fully met |
| TDD | Test-Driven Development workflow — write tests first, then implement |

### 8.3 Magic Keywords

Type these keywords naturally in your prompt to trigger specific modes:

| Keyword | Effect |
|---------|--------|
| autopilot | Full autonomous execution from idea to code |
| ralph | Persistence mode — runs until verified complete |
| ralplan | Iterative planning with consensus structured deliberation |
| ulw / ultrawork | Maximum parallelism with concurrent agents |
| team | Spawns a team of coordinated agents |
| deep-interview | Socratic questioning to clarify vague ideas before execution |
| deepsearch | Enhanced search for finding files and modules across large codebases |
| deep-analyze | Deep analysis of problems (e.g. why tests are failing) |
| tdd | Test-Driven Development workflow |
| plan | Planning interview before execution |

### 8.4 Smart Model Routing

OMC automatically routes tasks to the right model: Haiku for simple tasks, Sonnet for standard work, Opus for complex reasoning. This saves 30-50% on tokens with no manual configuration.

### 8.5 Cross-AI Orchestration

OMC can orchestrate other AI providers for specialist tasks: Codex for deep code review and security analysis, Gemini for visual analysis and 1M token context for large files.

### 8.6 All OMC Commands

| Command | Purpose |
|---------|---------|
| `/spawn` | Start a background agent on a specific task |
| `/status` | Show status of all running agents |
| `/focus` | Switch focus to a background agent |
| `/merge` | Merge results from agents and terminate them |
| `/kill` | Terminate a background agent |
| `/log` | Show detailed logs for a specific agent |
| `/oh-my-claudecode:autopilot` | Autonomous execution from idea to code |
| `/oh-my-claudecode:ultrawork` | Parallel agent execution |
| `/oh-my-claudecode:ralph` | Persistent execution until verified complete |
| `stopomc` / `cancel` | Cancel active orchestration |

### 8.7 /batch — Parallel Codebase Changes

`/batch` orchestrates large-scale changes across a codebase in parallel. Describe the change, and Claude decomposes it into 5-30 independent units, spawning one background agent per unit in isolated git worktrees.

Examples:

```
/batch migrate src/ from Solid to React
/batch replace all uses of lodash with native equivalents
/batch add type annotations to all untyped function parameters
/batch rename all database columns from camelCase to snake_case
```

Only works when units are independent. If one unit depends on another, use standard sessions or agent teams instead.

### 8.8 /simplify — Post-Implementation Cleanup

`/simplify` spawns three review agents in parallel to clean up code you just wrote:

- **Agent 1**: checks code reuse and duplication
- **Agent 2**: checks overall code quality
- **Agent 3**: checks efficiency

Run it after implementing a feature that works. It operates at the architectural level — code structure, algorithm efficiency, design decisions — not formatting.

### 8.9 Installing OMC

Install with:

```bash
$ claude /plugin install OMC
```

## 9. Slash Commands

### 9.1 The /help System

List all available slash commands:

```bash
$ claude /help   # Shows all commands and their syntax
```

Show details about a specific command:

```bash
$ claude /help /spawn
```

### 9.2 Common Slash Commands

| Command | Purpose |
|---------|---------|
| `/quit` | End the session and exit |
| `/rewind` | Undo your last message without losing context |
| `/clear` | Clear context window — use when switching tasks |
| `/context` | Show detailed token usage breakdown |
| `/mcp` | Show MCP server status and per-server token cost |
| `/logs` | Show Claude Code runtime logs |
| `/fast` | Toggle fast mode |
| `/compact` | Compress the conversation to fit more context |
| `/batch` | Parallel codebase changes |
| `/simplify` | Post-implementation cleanup |

## 10. Commands Reference

Complete alphabetical reference of all commands:

| Command | Purpose |
|---------|---------|
| `/batch` | Parallel codebase changes — spawns agents per unit in isolated worktrees |
| `/clear` | Clear context window |
| `/compact` | Compress context to fit more conversation |
| `/context` | Show detailed token usage breakdown |
| `/fast` | Toggle fast mode on/off |
| `/focus` | Switch focus to a background agent |
| `/help` | Show help for all commands or a specific command |
| `/kill` | Terminate a background agent |
| `/log` | Show logs for a specific agent |
| `/logs` | Show runtime logs |
| `/mcp` | Show MCP server status and token cost |
| `/merge` | Merge results from agents back into main session |
| `/plugin list` | List available plugins |
| `/plugin install` | Install a plugin |
| `/quit` | End the session |
| `/rewind` | Undo your last message |
| `/simplify` | Post-implementation cleanup |
| `/spawn` | Start a background agent |
| `/status` | Show status of running agents |
| `/worktree` | Create or switch git worktrees |

## 11. Troubleshooting

### 11.1 Session Disconnects

If your session disconnects unexpectedly:

- Check your internet connection (Claude Code requires stable connectivity)
- Check API key validity: `claude login`
- Check rate limits: `/logs` to see error messages
- If the problem persists, start a new session

### 11.2 Claude "Getting Dumber"

Symptoms: Claude gives increasingly generic answers, forgets earlier instructions, produces lower-quality code.

Root cause: Context pollution (see Section 2.5).

Solution:

1. Run `/context` to see token breakdown
2. If conversation is > 50% of context, use `/clear` and start fresh
3. Check `/mcp`; disable unused servers
4. Verify CLAUDE.md is concise and relevant

### 11.3 Agent Deadlocks

If agents are deadlocked (all waiting for each other):

```bash
$ claude /kill --all   # Kill all background agents
$ /merge               # Re-merge any in-flight changes
```

### 11.4 Build Failures After Implementation

Claude delivered code that compiles locally but fails in CI:

- Paste the CI failure log into a new session: "This build fails in CI with this error. Fix it."
- Include the full error output, not just the line number
- Mention if the failure is environment-specific (Linux vs macOS, Python 3.9 vs 3.11, etc.)

## 12. Case Study

### 12.1 Project Overview

A real-world migration project replacing a legacy desktop application with a modern, multi-tenant web platform.

Tech stack:

- Backend: Node.js, Express, TypeScript, Prisma ORM
- Database: SQL Server (not Postgres), with complex relational schema
- Frontend: React 18, Tailwind CSS, React Router
- DevOps: Azure Container Instances (ACI), GitHub Actions

The project replaces a VB6 desktop application built in the late 1990s that is still used in production. The migration preserves all business logic while adding multi-tenancy, modern security (JWT + LDAP), real-time collaboration, and a web-based interface.

### 12.2 CLAUDE.md Structure

The project's CLAUDE.md encodes:

- Token limits and escalation thresholds
- Prisma + SQL Server quirks (no cascade deletes, foreign key ordering)
- Exact patterns for new modules: where services live, how they interface with controllers, test setup
- Security rules (JWT parsing, LDAP integration, no PII in logs)
- Performance targets (response times < 200ms, queries < 100ms)

### 12.3 Key Challenges

Early sessions revealed three categories of problems:

1. **SQL Server Gotchas**: Prisma + SQL Server has edge cases Prisma + Postgres doesn't. Multiple cascade paths fail. Some migrations fail on second run. Claude needed explicit rules in CLAUDE.md.

2. **Legacy Data Mapping**: The legacy system used three-letter codes for status values. These had to map to enums in the new schema. A "Legacy Mapping" skill prevented repeated mistakes.

3. **Multi-Tenancy Isolation**: Every query must filter by tenant_id. One missing filter leaks data. A post-commit hook caught 15 violations before they reached staging.

### 12.4 Metrics

After 6 months of Claude Code usage:

- Feature implementation (request to verified): **4-7 hours** (was 2-3 weeks with manual development)
- Bug fixes (triage to production): **30-45 minutes** (was 3-5 days)
- Zero regressions traced to Claude implementation (all caught in testing)
- Code review turnaround: eliminated (code verified before submission)

## 13. Lessons from Production

### 13.1 Critical Patterns

Production experience uncovered critical patterns worth encoding:

| Pattern | Lesson |
|---------|--------|
| Foreign Key Cascades | SQL Server rejects multiple cascade paths on the same table. Use `onDelete: NoAction` on secondary relations and handle cascades in application code |
| Adapter Imports | Import from `@prisma/adapter-mssql`, not the generic adapter package |
| Feedback Loops | Any automated function that both produces and scans the same resource must exclude its own output to prevent infinite loops |
| Emergency Disables | Track exactly what was disabled. Re-enable and verify all functions after the fix deploys |

### 13.2 The Replace-Don't-Append Pattern

One of the most impactful operational patterns: the **replace-don't-append** rule for shared context files.

Rule: Never append to shared context files. Always replace the entire content. Keep it under 30 lines. This prevents "Prompt is too long" errors that silently break Claude's ability to read the file.

Why this matters: shared context files are read by every Claude session via CLAUDE.md. If sessions keep appending, the file grows unbounded. Once it exceeds the context window, Claude silently drops it — losing all shared state. The fix: every update overwrites with only the current state.

### 13.3 Multi-Agent Safety Rules

Projects using multi-agent orchestration discovered critical safety rules through painful experience:

| Rule | Rationale |
|------|-----------|
| No git stash in sub-agents | Sub-agents that stash can corrupt the working tree for the parent agent. Use worktrees for isolation instead |
| No branch switching | A sub-agent switching branches will confuse every other running agent. Each agent should work on its current branch only |
| Scope commits tightly | Each sub-agent should only commit the files it modified. Never use `git add -A` in a multi-agent context |
| Exit cleanly on failure | If a sub-agent fails, it must report the failure clearly rather than attempting recovery that might conflict with the parent |

### 13.4 Context Preservation

Important decisions and discoveries must survive across Claude sessions. Use a structured approach:

- **tasks.json** — Structured task tracking with status, priority, and context fields
- **PROJECT_NOTES.md** — Freeform decision log with dated entries. Updated immediately after architectural or technical decisions
- **STRUCTURE.json** — Machine-readable map of the codebase: modules, paths, purposes, dependencies

Even without a framework, the "dated decision log" pattern is worth adopting. Add a `## Session Notes` section to your PROJECT_NOTES.md and record every significant architectural decision with its context.

### 13.5 Local Plugin Marketplaces

Rather than stuffing everything into CLAUDE.md, encapsulate domain-specific knowledge into reusable plugins that can be versioned and shared.

```json
// In .claude/settings.json
{
  "extraKnownMarketplaces": {
    "your-project-plugins": {
      "source": {
        "source": "directory",
        "path": "./plugins"
      }
    }
  }
}
```

This treats a local `plugins/` directory as a plugin marketplace. Plugins load without depending on external registries and can be versioned alongside your project code.

## 14. Recommended CLAUDE.md Template

Based on the patterns above, every project should start with a CLAUDE.md that includes these sections at minimum:

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

### 14.1 Hook Recipes to Adopt

For any TypeScript project, install at minimum: auto-format, build-watcher, pre-commit-gate, and migration-guard. See Section 3.3 for details.

### 14.2 Skills Worth Creating First

Custom skills give Claude deep domain knowledge about your specific project. Prioritize:

1. **Module scaffolding skill** — Generates new backend modules (service + controller + DTO + spec) or frontend pages (component + route + API hook) following your project's exact patterns. Eliminates 80% of boilerplate errors.

2. **Database operations skill** — Understands your schema and generates correct migrations, seed data, and relation handling. Especially valuable for SQL Server projects where Prisma has edge cases.

3. **Testing patterns skill** — Knows your test setup (Jest config, mock patterns, fixture locations) and generates tests that actually pass on first run.

4. **Legacy migration mapping skill** — Maps legacy module names, function signatures, and data access patterns to their modern equivalents. The highest-value skill for accelerating any migration project.

Skills are YAML frontmatter + markdown body files stored in `.claude/skills/`. See Section 3.4 for the creation format.

As a general principle, review CLAUDE.md after every major model release. Instructions that compensate for model weaknesses often become unnecessary — and leftover instructions waste context tokens.
