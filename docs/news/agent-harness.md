---
title: Agent Harness — what pros understand
parent: News & Research
nav_order: 17
---
# Agent Harness: The Buzz Everyone's Now Using (But Only Pros Understand)

**Source:** Joe Njenga, [Agent Harness: The Buzz Everyone's Now Using (But Only Pros Understand)](https://medium.com/ai-software-engineer/agent-harness-the-buzz-everyones-now-using-but-only-pros-understand-f4c38ae74045) (Medium / AI Software Engineer, mid-April 2026)

## Key takeaways

- **"Agent Harness" is the community term of art** for the layer between your raw model and your codebase.
- The harness is **CLAUDE.md + hooks + slash commands + MCP connections** — everything that shapes how the model behaves on your code.
- The key distinction most users miss: **CLAUDE.md is advisory (guidance). Hooks are enforcement (deterministic).** Understanding this separates power users from casual users.
- Related sources have coined specific terms: *"LLMs don't just hallucinate, they rationalize"* (Hightower), *"the orchestrator was missing"* (Rezvani), *"90% of users are missing the most powerful feature"* (ZIRU).

## What the "harness" actually is

The harness is everything you control that shapes the model's behaviour without changing the model itself:

1. **CLAUDE.md** — context / guidance loaded into every session
2. **Hooks** — deterministic shell scripts fired on specific events (PreToolUse, PostToolUse, UserPromptSubmit, Stop)
3. **Slash commands** — reusable prompt templates / skill invocations
4. **MCP servers** — external tools the agent can call
5. **Skills** — modular packages that extend capabilities
6. **Sub-agents** — parallel workers the main agent spawns

## The advisory-vs-enforcement distinction

- **CLAUDE.md** is guidance. The model may follow it, may not. Opus 4.7's literal instruction-following changes this — 4.7 follows CLAUDE.md more faithfully than 4.6 did, which makes authority language matter more (see [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/)).
- **Hooks** are enforcement. The harness runs them deterministically — they cannot be bypassed by prompt engineering. Block commits, reject dangerous tool calls, run tests automatically.

Get this wrong and you think you've constrained the agent when you've just suggested behaviour.

## The related vocabulary landing in April 2026

The wider community is converging on shared language:

- **"Agent Harness"** (Joe Njenga) — the CLAUDE.md + hooks + commands + MCPs layer
- **"Rationalisation"** (Rick Hightower) — the failure mode where LLMs skip work and produce fluent excuses
- **"The orchestrator was missing"** (Reza Rezvani) — the layer above worker agents that adds decomposition, parallelism, clean main thread
- **"90% of users are missing the most powerful feature"** (ZIRU) — the framing for evangelising the harness concept
- **"Harness Engineering"** (Rick Hightower) — treating the harness layer as a first-class engineering discipline

## Why it matters for Harris / Constellation

Four-project CLAUDE.md files (Wraith, ACT, Centurion, NanoClaw) are the most leveraged thing in your setup. Every Claude Code session across the four projects reads them. If they're guidance-language, Opus 4.7 now follows them better; if they're suggestion-language, 4.7 pushes back more. Upgrading to authority-language is a one-hour task with compound returns across the entire engineering team.

## Related Playbook pages

- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — the Cialdini playbook for hardening CLAUDE.md
- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — the orchestrator layer above worker agents
- [Knowledge & Context]({{ site.baseurl }}/docs/knowledge-and-context/) — the CLAUDE.md schema as a layer in the Karpathy wiki pattern
- [Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/) — why 4.7 amplifies the advisory-vs-enforcement distinction
