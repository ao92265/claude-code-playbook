---
title: Building a first Managed Agent from scratch
parent: News & Research
nav_order: 25
---
# How Claude Code Built My First Claude Managed Agent (From Scratch)

**Source:** Joe Njenga, [How Claude Code Built My First Claude Managed Agent (From Scratch)](https://medium.com/@joe.njenga/how-claude-code-built-my-first-claude-managed-agent-from-scratch-980fb6ac4872) (Medium, 2026-04-09)

## Key takeaways

- **Concrete build log** — Njenga uses Claude Code itself to build a production-ready Managed Agent on Anthropic's platform.
- Published one day after [Anthropic's Managed Agents public beta launch]({{ site.baseurl }}/docs/news/managed-agents-launch/).
- Demonstrates the "days, not months" time-to-production claim with a real example.
- Good reference for tech leads evaluating Managed Agents vs existing orchestration.

## The setup

On 8 April 2026 Anthropic released Managed Agents as a public beta. Njenga sat down with Claude Code and built a production agent *using* the new service. Article is the walkthrough.

## What Njenga built

A production-ready Claude Managed Agent covering:

- Agent definition (tasks, tools, guardrails)
- Deployment to Anthropic's infrastructure
- End-to-end testing
- Integration into an existing workflow

## What the walkthrough validates

- The "prototype to production in days" claim holds for simple agent shapes
- Claude Code itself is a capable tool for building Managed Agents (meta-loop)
- The API surface is small enough that one engineer can internalise it in a session

## What it doesn't address

- Multi-agent coordination (that's behind a request form at `claude.com/form/claude-managed-agents`)
- Advanced governance (delegation-policy visibility, per-model attribution — see the [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) page)
- Integration with existing non-Anthropic orchestration (LangGraph, CrewAI, OMC) — Managed Agents is a replacement, not a layer on top

## The broader comparison to make

When reading this article, hold it alongside:

- [Anthropic Managed Agents launch]({{ site.baseurl }}/docs/news/managed-agents-launch/) — the structural-advantage argument (context continuity without text serialisation)
- [The Orchestrator Was Missing]({{ site.baseurl }}/docs/news/orchestrator-was-missing/) — Rezvani's third-party orchestrator pattern; how does it compare?
- [BMad Autonomous Development]({{ site.baseurl }}/docs/bmad/) — `/bad`, another third-party pattern worth comparing

If you're currently building on third-party orchestration, the decision to stay or migrate is the key question this article helps you answer.

## Related Playbook pages

- [Anthropic Managed Agents launch]({{ site.baseurl }}/docs/news/managed-agents-launch/) — the feature announcement
- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — full comparison with third-party patterns
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) — governance considerations for Managed Agents in regulated verticals
