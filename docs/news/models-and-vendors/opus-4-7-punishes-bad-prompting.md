---
title: Opus 4.7 punishes bad prompting
parent: Models & Vendors
grand_parent: News & Research
nav_order: 2
permalink: /docs/news/opus-4-7-punishes-bad-prompting/
---
# Opus 4.7 — the first model that punishes bad prompting

**Source:** Joe Njenga, [Claude Opus 4.7 Is Here (The First Model That Punishes Bad Prompting)](https://medium.com/ai-software-engineer/claude-opus-4-7-is-here-the-first-model-that-punishes-bad-prompting-70010fe53690) (Medium, 2026-04-16, 7 min read)

## Key takeaways

- Opus 4.7 GA across Claude products, API, Amazon Bedrock, Google Vertex AI, and **Microsoft Foundry** — zero migration friction for Azure tenants.
- **First Anthropic model shipping with safeguards** that detect and block high-risk cybersecurity requests. Legitimate security work needs the new Cyber Verification Program.
- **`xhigh` effort level is now the default** across all Claude Code plans.
- **New `/ultrareview` slash command** — dedicated review session, 3 free for Pro/Max users.
- **Auto mode extended to Max users** — fewer permission prompts during agentic runs.
- **Task budgets** in public beta on the API.
- **Njenga's Windows upgrade failed; Linux worked** — platform note worth knowing.

## What changed at the model level

### 1. Instruction following (the biggest shift)

> "Previous models interpreted prompts incorrectly at times and would skip parts, reorder steps, or make small judgment calls on your behalf. Opus 4.7 takes your instructions strictly."

This is great when your prompts are clean. It also means **older prompts written for Opus 4.6 or earlier can produce unexpected results.** Production prompts and agent harnesses need re-tuning.

### 2. Higher-resolution vision

- Accepts images up to **2,576 pixels on the long edge** (~3.75 megapixels)
- **3× the resolution** of previous Claude models
- Use cases: dense screenshots in computer-use agents, complex diagrams/dashboards, pixel-perfect UI references

### 3. Real-world work performance

- **State-of-the-art on GDPval-AA** — third-party evaluation covering finance, legal, knowledge work
- Internal testing: better finance-analyst performance than 4.6 — more rigorous analyses, more professional presentations
- Generates better interfaces, slides, and docs

### 4. Memory

> "Opus 4.7 is better at using file system-based memory across long multi-session work. It remembers important notes from earlier sessions and uses them to move on to new tasks without needing a full re-briefing each time."

For agentic workflows spanning hours or days, this means less context-loading and more actual progress.

**Njenga's summary:** *"Opus 4.7 is less of a chat model and more like a system you can delegate to."*

## Cybersecurity safeguards — and the opt-out

Opus 4.7 is the **first Anthropic model to ship with safeguards detecting and blocking requests tied to prohibited or high-risk cybersecurity uses.**

For security professionals doing legitimate work — vulnerability research, penetration testing, red-teaming — Anthropic opened a **Cyber Verification Program** at claude.com to access the model without those restrictions. If your team does any of this work, apply before the 4.7 upgrade or you'll hit unexplained refusals.

## What changed in Claude Code

### `xhigh` effort level (new default)

The `xhigh` tier sits between `high` and `max`. More thinking than `high` without paying the full latency cost of `max`. **Now default across all Claude Code plans.** Anthropic recommends starting at `high` or `xhigh` for coding and agentic work.

### `/ultrareview` — new slash command

> "The new `/ultrareview` slash command spins up a dedicated review session that reads through your changes, and flags bugs and design issues a careful reviewer would catch. It is not a linter but runs a proper code review before you merge."

Pro and Max users get **3 free `/ultrareview` invocations** to try it.

### Auto mode for Max users

Claude makes decisions on your behalf during a session. Longer tasks run with fewer interruptions — between fully supervised and skipping-all-permissions. Removes the constant stop-and-approve for multi-file agentic coding.

### Task budgets on the API (public beta)

Guide how Claude spends tokens across a longer run so the model can prioritise work. Fixes the classic failure where an agent spends its context window on exploration and runs out of room.

## Platform gotcha

Njenga's Claude Code Windows upgrade to access 4.7 **failed**. Moving to Linux worked. Worth watching for if you roll out across a Harris team on mixed platforms.

## 1M-context variant

```
/model claude-opus-4-7[1m]
```

invokes the 1M-context variant in Claude Code. UI may render as "Opus 4 (1M context)."

## Pricing

- **$5 per million input tokens**
- **$25 per million output tokens**
- Unchanged from Opus 4.6
- API identifier: `claude-opus-4-7`
- Positioned **below Claude Mythos** in capability (Mythos still on limited release)

## Njenga's personal verdict

> "Claude Opus 4.7 is ideal for software engineers already using Opus 4.6 in production. I have limited Claude Opus 4.6 to only a few complex tasks since I find it way expensive for simple tasks, its good for show off but not practical for business. The `/ultrareview` command and auto mode for Max users are the two updates I am keeping an eye on, but they are not in my daily workflow."

## Related Playbook pages

- [Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/) — full feature reference + migration checklist
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) — Cyber Verification Program integration
- [Cost & Observability]({{ site.baseurl }}/docs/cost-and-observability/) — measuring xhigh-default cost impact
- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — 1M context for large-codebase work
