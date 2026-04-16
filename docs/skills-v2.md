---
title: Skills v2
nav_order: 2
parent: "Skills & Extensibility"
---
# Skills 2.0 — Programmable Agents

Skills 2.0 unified custom instructions and agent commands under a single `.claude/skills/` directory model. Where Skills 1.0 was passive context (markdown the agent reads), Skills 2.0 is active execution — skills can now spawn isolated subagents, inject live shell output, and declare full agent behavior in frontmatter.

> **Quick install:** `npx skills add <package>` — or drop a directory into `.claude/skills/` manually.

---

## What Changed in Skills 2.0

| Capability | Skills 1.0 | Skills 2.0 |
|:-----------|:-----------|:-----------|
| Format | Single SKILL.md file | Directory with SKILL.md + dependencies |
| Execution model | Passive context injection | Active: can spawn subagents via `context: fork` |
| Context budget | Shares main session window | Isolated 200k-token window per fork |
| Dynamic data | Static markdown only | `!` backtick syntax runs shell commands live |
| Agent control | None | `model`, `effort`, `maxTurns`, `disallowedTools` in frontmatter |
| Git isolation | None | `isolation: worktree` for parallel branch work |
| Background jobs | None | `background: true` for fire-and-forget execution |
| Interoperability | Claude Code only | Open standard (agentskills.io) — works across AI tools |

---

## Key Features

### 1. Context Fork (`context: fork`)

The most significant change in 2.0. When a skill sets `context: fork` in its frontmatter, Claude Code spawns an isolated subagent with its own **200,000-token context window** rather than sharing the main session's context.

```yaml
---
name: code-review
context: fork
model: sonnet
---
```

Benefits:
- The skill's work does not pollute your main session history
- Long-running agent tasks (full repo review, deep refactor planning) don't compress your main context
- Multiple forked skills can run in parallel without context interference
- Worst case: the fork fails or goes wrong — your main session is unaffected

Use `context: fork` for any skill that does substantial read/analysis work or spawns many tool calls.

### 2. Dynamic Context Injection

Skills can embed live shell output directly into the prompt using backtick syntax prefixed with `!`:

```markdown
---
name: project-status
---

Current branch: `!git branch --show-current`
Uncommitted changes: `!git status --short`
Recent commits: `!git log --oneline -10`
Failing tests: `!npm test 2>&1 | tail -20`
```

When the skill runs, each `!command` executes in the project root and its output replaces the backtick expression. The agent receives a fully resolved prompt with real current state — no manual copy-paste required.

**Common uses:**
- Inject current git state before a code review
- Pull environment variable names from `.env.example`
- Include the last N lines of a log file for debugging
- Show current dependency versions before an upgrade plan

### 3. Agent Frontmatter Schema

Full set of supported frontmatter keys in Skills 2.0:

```yaml
---
name: skill-name                    # Required. Used for /skill-name invocation
description: One-line summary       # Used for relevance matching and skills.sh listings
context: fork                       # fork | inherit (default: inherit)
model: haiku                        # haiku | sonnet | opus (default: inherits session model)
effort: low                         # low | medium | high (default: low)
maxTurns: 20                        # Maximum agent turns before stopping (default: unlimited)
disallowedTools:                    # Tools this skill cannot use
  - Bash
  - Write
isolation: worktree                 # worktree | none (default: none)
background: false                   # true | false — run without blocking main session
memory: project                     # user | project | local (default: none) — persistent memory scope
initialPrompt: "Start analysis"     # Auto-submit a first turn when the agent launches (v2.1.83)
paths:                              # YAML list of globs — skill loads only when matching files are touched (v2.1.84)
  - "src/**/*.ts"
  - "tests/**/*.test.ts"
---
```

> **New in v2.1.84:** `paths` frontmatter accepts a YAML list of globs, making skills behave like path-scoped rules — they only activate when relevant files are in play. This reduces the ~100-token startup cost for skills that aren't relevant to the current task.

**`isolation: worktree`** creates a fresh git worktree for the skill's execution. Changes are made on a branch, not in your working tree. Use this for skills that touch many files (batch refactors, codebase-wide search-and-replace).

**`disallowedTools`** lets you build read-only skills. A code review skill that sets `disallowedTools: [Bash, Write, Edit]` can analyze but never modify — useful for sharing skills across a team where you want review without write access.

---

## Built-in Skills Reference

Four skills ship with Claude Code out of the box. They live at `~/.claude/skills/` after installation.

### `/simplify`

Runs **3 parallel review agents** that each analyze your code from a different lens, then synthesizes their findings:

- Agent 1: Complexity and cognitive load
- Agent 2: Naming and readability
- Agent 3: Unnecessary abstractions and dead code

Usage:
```
/simplify src/services/payment.ts
/simplify                          # Reviews files changed in current session
```

Internally uses `context: fork` so review output doesn't bloat your working context.

### `/batch`

Executes codebase-wide changes in **isolated git worktrees** — safe to run on large repos without touching your working tree until you review and merge.

```
/batch "Update all API calls to use the new fetchWithRetry wrapper"
/batch "Add JSDoc comments to all exported functions in src/utils/"
```

How it works:
1. Creates a git worktree at `.git/worktrees/batch-<timestamp>`
2. Runs the change across all matching files in parallel agents
3. Produces a diff summary for your review
4. You `git merge` or discard — no commits happen automatically

### `/debug`

Structured debugging workflow with explicit hypothesis-test cycles:

```
/debug "TypeError: Cannot read property 'id' of undefined in checkout flow"
```

The skill formats a structured investigation:
1. Reproduce: minimal case to confirm the error
2. Hypothesize: 3 candidate root causes with likelihood scores
3. Test: targeted tool calls to confirm/eliminate each hypothesis
4. Fix: implement the confirmed root cause only
5. Verify: run affected tests, confirm fix

Avoids the "randomly change things and hope" pattern that wastes context.

### `/claude-api`

API integration assistant for working with the Claude API directly — useful when building applications on top of Claude rather than just using Claude Code itself:

```
/claude-api "How do I implement streaming responses in Node.js?"
/claude-api "Show me tool use with parallel tool calls"
```

Fetches current documentation and produces copy-paste ready code examples for the requested API pattern.

---

## Creating a Custom Skill

Skills are directories. The minimum structure:

```
.claude/skills/
└── my-skill/
    └── SKILL.md
```

### Example: Dependency Audit Skill

```
.claude/skills/
└── dep-audit/
    ├── SKILL.md
    └── scripts/
        └── audit.sh          # Optional: helper scripts
```

**`SKILL.md`:**

```markdown
---
name: dep-audit
description: Audit npm dependencies for vulnerabilities and outdated packages
context: fork
model: haiku
effort: low
maxTurns: 15
disallowedTools:
  - Write
  - Edit
---

# Dependency Audit

Current package versions:
`!cat package.json | jq '.dependencies, .devDependencies'`

Known vulnerabilities:
`!npm audit --json 2>/dev/null | jq '.vulnerabilities | length' || echo "npm audit unavailable"`

Outdated packages:
`!npm outdated 2>/dev/null || echo "No outdated packages or npm outdated unavailable"`

## Task

Review the above dependency state and produce a prioritized report:

1. **Critical:** Packages with known CVEs — must update immediately
2. **High:** Major version behind with breaking changes risk
3. **Low:** Minor/patch updates available, safe to batch

For each critical/high item, include the exact `npm install` command to fix it.
Do NOT modify any files. Output the report only.
```

Invoke with `/dep-audit` from anywhere in the project.

### Adding Dependencies to a Skill

For skills that need companion files (scripts, templates, config):

```
.claude/skills/
└── db-migrate/
    ├── SKILL.md              # Instructions and frontmatter
    ├── templates/
    │   └── migration.sql.tmpl
    └── README.md             # Optional: human docs for the skill
```

Reference companion files in SKILL.md using relative paths. The agent receives the full directory as context.

---

## Migrating from Skills 1.0

If you have existing `.claude/skills/*.md` flat files (Skills 1.0 format), migration is straightforward:

**Before (1.0):**
```
.claude/skills/
└── code-review.md            # Single file, no frontmatter standard
```

**After (2.0):**
```
.claude/skills/
└── code-review/
    └── SKILL.md              # Same content + frontmatter header
```

Steps:
1. Create a directory with the skill name
2. Move or rename the `.md` file to `SKILL.md`
3. Add YAML frontmatter block at the top
4. Optionally add `context: fork` if the skill does substantial work

There is no breaking change — 1.0 flat files still work. The 2.0 directory format unlocks the new features.

---

## The Open Standard

Skills 2.0 implements the open agent skills specification at [agentskills.io](https://agentskills.io). The SKILL.md format is tool-agnostic: the same skill directory works in Claude Code, Codex, Cursor, and any other AI tool that implements the spec.

This means:
- Skills you write are portable across tools your team uses
- Community skills from `npx skills add` work everywhere
- You can contribute skills to the open registry for others to install

The `skills.sh` package manager distributes community skills that conform to this standard. See [skills-ecosystem.md](skills-ecosystem.md) for the full package manager guide.

---

## Tips

- **Default to `context: fork`** for any skill that reads many files or runs for more than a few turns. It costs nothing and protects your main context.
- **Use `model: haiku`** for skills that do simple searches, audits, or formatting. Reserve `sonnet`/`opus` for skills that need reasoning.
- **Cap `maxTurns`** on skills you share with the team. Unbounded skills running on slow machines or large repos can run for many minutes.
- **Read-only skills should set `disallowedTools`** to prevent accidental writes. Trust but verify — especially for skills installed from external packages.
- **Dynamic injection replaces manual copy-paste.** If you're ever telling the agent "here's my current git status", that's a signal to move it into a skill with `!git status`.
- **Invoke critical skills explicitly.** Trigger reliability is probabilistic — Claude decides whether a skill is relevant. For workflows that must always fire, use `/skill-name` explicitly or implement the behavior as a hook instead.
- **Fewer skills is often better.** Community data (r/claude, 1,072 upvotes): one engineer tested 47 skills and found 40 made output worse by adding tokens and narrowing responses. The best skill is one you build yourself for your specific workflow. Install selectively.
- **Skills = model decides, hooks = system enforces.** If a behavior must always happen (formatting, linting, security checks), implement it as a hook. If it should usually happen (code review patterns, architectural guidance), implement it as a skill.

---

*See also: [skills-ecosystem.md](skills-ecosystem.md) — community package manager | [plugin-authoring.md](plugin-authoring.md) — distributing skills as plugins*
