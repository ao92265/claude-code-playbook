---
title: The Orchestrator Was Missing
parent: Knowledge Management
grand_parent: News & Research
nav_order: 2
---
# The Orchestrator Was Missing: Building an Internal Research Agent Around AutoResearch

**Source:** Reza Rezvani, [The Orchestrator Was Missing: Building an Internal Research Agent Around AutoResearch in Claude](https://alirezarezvani.medium.com/the-orchestrator-was-missing-building-an-internal-research-agent-around-autoresearch-in-claude-678b08a83c9b) (Medium, 2026-04-07)

## Key takeaways

- **Worker agents (iterative reasoning) need an orchestrator above them.** Worker-alone architectures fail on anything non-trivial.
- **The orchestrator adds: decomposition, parallelism, a clean main thread.**
- Rezvani's internal research-agent rebuild around Claude's AutoResearch pattern is the concrete case study.
- Maps directly onto ACT's positioning — the missing layer Rezvani describes *is* an orchestration platform.

## The thesis

> Worker agents (the ones that do iterative reasoning inside a single context) are necessary but not sufficient. Every non-trivial task needs an **orchestrator** above the worker:
>
> - **Decomposition** — break a big task into worker-sized pieces
> - **Parallelism** — run independent pieces concurrently
> - **Clean main thread** — don't pollute the user's conversation with worker-internal churn

Without the orchestrator you get context explosion, hallucination creep, and degrading quality around step 3 of any multi-step reasoning (see the [CLI vs MCP piece]({{ site.baseurl }}/docs/news/cli-vs-mcp/) for Rezvani's data on this).

## Why this matters for ACT

ACT (Agent Control Tower) is explicitly an orchestration platform. Rezvani's article is community-validated vocabulary + architecture for exactly what ACT is building.

Compare:

- **ACT's architecture** vs Rezvani's orchestrator pattern — what overlaps, what doesn't
- **OMC's notepad / project-memory / state layers** vs the "clean main thread" problem — OMC serialises to text; Anthropic's Managed Agents doesn't (see [Managed Agents launch]({{ site.baseurl }}/docs/news/managed-agents-launch/))
- **AutoResearch** as Anthropic's first-party orchestration seed — worth studying as the public reference

## The concrete case

Rezvani walks through building an internal research agent:

1. **Worker layer:** AutoResearch-style iterative reasoning for specific research queries
2. **Orchestrator layer:** decomposes a research question into sub-queries, runs them in parallel, synthesises the results
3. **Main thread:** stays clean — user sees the synthesis, not the worker-level exploration

Output: a research agent that handles genuinely complex questions without losing coherence.

## Where the article is worth reading in full

For ACT's architectural decisions specifically, this 13-minute read is a high-priority reference. The Email 22 notes in the digest summarise it, but the primary source has concrete code/config examples worth pulling through.

## Related Playbook pages

- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — the full orchestrator pattern reference
- [Anthropic Managed Agents launch]({{ site.baseurl }}/docs/news/managed-agents-launch/) — Anthropic's first-party orchestrator
- [The CLI vs MCP Debate]({{ site.baseurl }}/docs/news/cli-vs-mcp/) — Rezvani's data on what breaks without a proper orchestrator layer
- [BMad Autonomous Development]({{ site.baseurl }}/docs/bmad/) — `/bad` is another concrete orchestrator implementation
