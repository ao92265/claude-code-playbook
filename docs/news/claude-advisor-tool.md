---
title: Claude Advisor Tool — sub-agent pattern, inverted
parent: News & Research
nav_order: 54
---
# Anthropic Just Made Cheap Models Think Like Opus (Claude Advisor Tool Is Wild)

**Source:** Two articles in the Email 08 bundle (2026-04-13):
- *Anthropic Just Made Cheap Models Think Like Opus (Claude Advisor Tool Is Wild)*
- *Claude's Advisor Tool: The Sub-Agent Pattern, Inverted*

## Key takeaways

- **The sub-agent pattern, inverted.** Normally: Opus delegates to cheaper sub-agents. Advisor: cheaper models consult Opus for difficult moments.
- **"Makes cheap models think like Opus"** — runs most of the session on Haiku/Sonnet but pulls in Opus's reasoning when the current model gets stuck.
- Direct implication for cost-routing architecture: you can ship most workloads on cheaper models and still get Opus-level outcomes on hard problems.

## The inversion explained

```
Normal pattern:
  Opus (expensive, always available)
    └─ delegates to Sonnet/Haiku for simple subtasks

Advisor pattern:
  Sonnet/Haiku (cheap, default)
    └─ pulls in Opus *only* when stuck
```

The normal pattern starts expensive and tries to save money by delegating down. The Advisor pattern starts cheap and consults up. **Cheaper in the average case, still gets Opus quality when it actually matters.**

## Why this matters for cost-routing

For any Harris / Constellation product that routes between model tiers:

- **Current architecture often**: pick a tier, stick with it for the session
- **Advisor pattern alternative**: start Sonnet, escalate to Opus for specific hard moments
- **Combined with task budgets** (Opus 4.7 public beta): reasoning-depth becomes a per-task dial

This could materially change ACT's model-routing logic. Worth reading both articles to understand the mechanism.

## Related Playbook pages

- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — full orchestration reference
- [Cost & Observability]({{ site.baseurl }}/docs/cost-and-observability/) — measuring routing effectiveness
- [Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/) — task budgets in public beta
