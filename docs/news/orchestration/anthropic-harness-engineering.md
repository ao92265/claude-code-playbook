---
title: Anthropic's Harness Engineering — Two Agents, One Feature List
parent: Multi-Model Orchestration
grand_parent: News & Research
nav_order: 4
permalink: /docs/news/anthropic-harness-engineering/
---
# Anthropic's Harness Engineering: Two Agents, One Feature List, Zero Context Overflow

**Source:** Rick Hightower, cited in Medium Daily Digest of 2026-04-07 (Email 23). 18 min read, 178 claps.

## Key takeaways

- **Concrete demonstration of Anthropic's "harness engineering" approach** to solving context-window boundary problems.
- Two-agent pattern: one agent maintains the feature list, another implements — neither overflows context.
- This is the engineering discipline behind Opus 4.7's long-session persistence gains.
- Pair with Hightower's [Superpowers / Cialdini]({{ site.baseurl }}/docs/news/superpowers-cialdini/) (same author, complementary theme).

## What "harness engineering" means

The harness is everything around the model that manages state, memory, context, and delegation. **Harness engineering** treats that layer as a first-class engineering discipline, not an afterthought.

Anthropic's own approach (per Hightower's analysis):

- Split complex tasks across multiple agents so none holds the full context
- Coordinate via a shared structured artefact (feature list)
- Each agent's context stays within limits
- Result: long sessions don't degrade the way single-context sessions do

## Why this is the real mechanism behind Opus 4.7's persistence gains

When [Rezvani's article]({{ site.baseurl }}/docs/news/opus-4-7-behavioral-release/) mentions Opus 4.7's persistence-through-tool-failures (pattern 5), the underlying enabler is harness engineering — the *model* behaving better is only half the story; the *harness* is what keeps the model usable over many hours.

## Harness engineering articles (broader series by Hightower)

- *The $9 Disaster: What Anthropic's Harness Design Paper Teaches Us About Building Autonomous AI*
- *Harness Engineering vs Context Engineering: The Model is the CPU, the Harness is the OS*
- *LangChain Deep Agents: Harness and Context Engineering*
- *Beyond the AI Coding Hangover: How Harness Engineering Prevents the Next Outage*
- *LangChain's Harness Engineering: From Top 30 to Top 5 on Terminal Bench 2.0*
- *OpenAI's Harness Engineering Experiment: Zero Manually-Written Code*

## Related Playbook pages

- [Superpowers / Cialdini]({{ site.baseurl }}/docs/news/superpowers-cialdini/) — Hightower's prompt-discipline companion piece
- [Agent Harness]({{ site.baseurl }}/docs/news/agent-harness/) — the community-vocabulary framing
- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — the harness-as-OS metaphor in practice
- [Opus 4.7 — the behavioural release]({{ site.baseurl }}/docs/news/opus-4-7-behavioral-release/) — what harness engineering delivers at the model level
