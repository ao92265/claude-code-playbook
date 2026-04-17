---
title: Paperclip — agents as a company
parent: News & Research
nav_order: 28
---
# Paperclip: The Open-Source Platform Turning AI Agents into an Actual Company

**Source:** Kristopher Dunham, [Paperclip: The Open-Source Platform Turning AI Agents into an Actual Company](https://medium.com/@creativeaininja/paperclip-the-open-source-platform-turning-ai-agents-into-an-actual-company-7348015c5bf7) (Medium, 2026-04-06)

## Key takeaways

- **Paperclip** is an open-source platform structuring AI agents as company roles (CEO, CTO, engineers, PMs).
- Competitive with — but distinct from — Anthropic Managed Agents.
- Worth knowing about even if you don't adopt: the design philosophy ("agents should inherit org-chart structure, not graph nodes") is an interesting data point for ACT architecture.
- Open-source = you can read the code, which is more than you can say for Managed Agents or Copilot Cowork.

## The pitch

Most multi-agent frameworks represent agents as nodes in a graph (LangGraph, AutoGen) or as roles in a pipeline (CrewAI). Paperclip structures them as a **company** — with departments, reporting lines, role definitions, and cross-team coordination.

The argument: **humans already know how companies work.** Operating an AI workforce using company semantics is less mental overhead than operating a graph.

## Why it matters (even if you don't adopt)

- **ACT comparison:** Paperclip's "agents-as-company" is a third architecture option alongside Rezvani's orchestrator pattern and Anthropic's Managed Agents. Worth comparing when making architectural decisions for ACT.
- **Open source:** read the code. Paperclip's repo documents design decisions in-source in a way Managed Agents can't (closed) and CrewAI doesn't explicitly.
- **Domain fit for regulated verticals:** company-structure semantics map onto compliance hierarchies (CRO, CISO, SOX auditor roles) more naturally than graph semantics.

## When to look at Paperclip

- You're evaluating multi-agent orchestration options for ACT or a similar platform
- You want an OSS alternative to compare against Anthropic Managed Agents
- You're designing for regulated customers and want a structure that maps onto corporate hierarchies

## When to skip it

- You're already committed to a multi-agent framework that works
- Your use cases are single-agent or light-orchestration
- Your team doesn't have the bandwidth to evaluate yet-another-framework

## Related Playbook pages

- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — full orchestration comparison
- [Anthropic Managed Agents launch]({{ site.baseurl }}/docs/news/managed-agents-launch/) — the first-party comparison point
- [BMad Autonomous Development]({{ site.baseurl }}/docs/bmad/) — another concrete pattern worth comparing
