---
title: Agent Memory
parent: Resources
nav_order: 35
---
# Agent Memory

Subagents can carry persistent state across sessions through the `memory:` frontmatter field. Different from CLAUDE.md (which is project context) and TodoWrite (which is in-session task state) — agent memory is a per-agent, append-only store the model reads at the start of every invocation.

## Three Scopes

| Scope | Storage | Visible to | When to use |
|-------|---------|------------|-------------|
| `user` | `~/.claude/agent-memory/<name>/MEMORY.md` | All projects, this user | Personal style preferences, vocab, tone |
| `project` | `.claude/agent-memory/<name>/MEMORY.md` | Anyone in this repo | Project conventions, decisions, glossary |
| `local` | `.claude/agent-memory/<name>/MEMORY.local.md` (gitignored) | Just you, this repo | WIP context, sensitive notes |

## Frontmatter Example

```yaml
---
name: code-reviewer
description: Reviews diffs against project conventions
model: sonnet
memory: project          # write to .claude/agent-memory/code-reviewer/MEMORY.md
skills: [test-first, security-check]
---

You are a senior reviewer. Before starting, read your MEMORY.md to recall
prior decisions and recurring nits. After review, append any new convention
under "## Conventions Learned" with a date stamp.
```

## Inject Limit

Claude Code auto-injects up to **the first 200 lines** of the agent's `MEMORY.md` on every invocation. Past that, the agent must explicitly Read the file. Keep memory tight — long memory files get truncated and the entries past line 200 silently never reach the model.

Recommended structure:

```markdown
# <agent> memory

## Conventions Learned
- [2026-04-12] Use `Result<T, E>` over throwing in shared/ — decided in #1842
- [2026-04-30] Tests live next to source as `*.test.ts`, never in `__tests__/`

## Open Questions
- Whether to migrate the legacy auth middleware (blocked on legal review)

## Vocabulary
- "Tenant" = paying customer org. "Workspace" = a tenant's project space.
```

## Combining Memory + Skills

`memory:` and `skills:` are independent. The model first sees memory (state), then the relevant skill content (instructions). Use memory for **what was decided**, skills for **how to do things**.

## Pitfalls

- **Memory is append-only by convention, not by enforcement.** A subagent can rewrite or delete its memory file. If you need durability, snapshot it to git or back it up.
- **Local memory is invisible to teammates.** Don't put load-bearing project decisions in `MEMORY.local.md`; promote them to `project` scope once stable.
- **Cross-agent memory needs a shared file.** If two agents need to coordinate, point them at the same project-scoped path explicitly via prompt — the `memory:` field is per-agent.
- **200-line truncation is silent.** Run `wc -l` on memory files in CI; warn if any exceeds 180 lines.

## When to Reach for It

Use agent memory when:
- The agent has a recurring role (reviewer, planner, on-call triager) and learns project nuance over time
- You want decisions to persist past `/clear`
- The state is too small for a database but too important to live in conversation history

Skip it when:
- The state belongs in CLAUDE.md (it's a project rule, not an agent-local note)
- The state is one-shot (use TodoWrite or notepad instead)
- The agent is single-use (planner agents that fire once per project)

## See Also

- [Skills 2.0](skills-v2.md) — frontmatter fields including `memory`
- [Knowledge & Context](knowledge-and-context.md) — CLAUDE.md vs memory vs notepad
- [Steering Files](steering-files.md) — the meta-pattern for persistent agent behaviour
