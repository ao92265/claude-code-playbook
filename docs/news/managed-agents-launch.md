---
title: Anthropic Managed Agents — public beta
parent: News & Research
nav_order: 12
---
# Introducing Claude Managed Agents, Now in Public Beta

**Source:** r/ClaudeAI, [u/ClaudeOfficial — "Introducing Claude Managed Agents, now in public beta"](https://www.reddit.com/r/ClaudeAI/comments/1sfz7a5/introducing_claude_managed_agents_now_in_public/) (2026-04-08). This is Anthropic's official launch thread.

## Key takeaways

- **API-only launch.** Named customers: Notion, Sentry, Rakuten, Asana, Vibecode.
- Anthropic runs the orchestration, state management, permissions layer — you define tasks, tools, guardrails.
- **Structural advantage over CrewAI / AutoGen / LangGraph:** first-party control of both orchestration and model enables context continuity across agent handoffs without text serialisation.
- Open question: whether Anthropic exposes enough control over delegation policy to diagnose orchestrator misrouting.
- Community sentiment is largely angry about usage limits rather than the feature itself.

## The announcement

> "Shipping a production agent meant months of work: infrastructure, state management, permissioning, and reworking agent loops with every model upgrade. Managed Agents handles all of that, with a suite of composable APIs for building and deploying agents at scale."

> "Define your agent's tasks, tools, and guardrails. We run it on our infrastructure, so you can go from prototype to production in days. And because it's built specifically for Claude, you get better agent outcomes with less effort."

> "Teams at Notion, Sentry, Rakuten, Asana, and Vibecode are already building with it."

### Links

- **Deploy quickstart:** `https://platform.claude.com/workspaces/default/agent-quickstart`
- **Multi-agent coordination (request access):** `http://claude.com/form/claude-managed-agents`
- **Blog:** `https://claude.com/blog/claude-managed-agents`

## Rakuten crossover

Rakuten also appeared in Opus 4.7's SWE-Bench 3× claim. Combined with being a Managed Agents launch customer, this suggests Rakuten is running a deep Anthropic-integrated stack worth studying.

## The technical argument — why this is structurally different

The buried-gold comment on the thread, from `Soft_Match5737`:

> "The key advantage of first-party managed agents over CrewAI/AutoGen/LangGraph is **context continuity**. Third-party frameworks shuttle messages between isolated API calls, which means every agent handoff loses the implicit reasoning state. When Anthropic controls both the orchestration and the model, they can maintain internal representations across agent boundaries without serializing everything to text."

This matters because **most third-party multi-agent orchestrators (OMC, LangGraph, CrewAI, AutoGen) serialise state to markdown/JSON between handoffs**. Managed Agents doesn't have to. If the structural claim holds in production, that's a real efficiency edge that no external framework can match.

## The open question — delegation visibility

Also from Soft_Match5737:

> "The real question is whether they expose enough control over the delegation policy. Most agent failures I have seen come from the orchestrator misrouting a subtask, not from the worker agent being bad. If managed agents give you visibility into why a task got delegated to which sub-agent, that alone makes it worth using over rolling your own."

Verify this before deploying to production scenarios where misrouting has business cost.

## Community reception — largely about usage limits, not the feature

The thread is dominated by angry consumer frustration rather than feature discussion:

- **Snowcatcat:** *"fix your usage limit issue first, everything else is meaningless."*
- **Syphari:** *"Doesn't matter if the service is down 98% of the time"* (43 upvotes)
- **Budget-Journalist-50:** *"Have you ever considered stopping the constant introduction of new, often unnecessary features and instead focusing on improving your existing infrastructure and user account management?"*
- **krill156 (Max plan):** *"Max. Literally can't use it at all right now, not on any model, times out every time after responding a few times. It's ate up 10% of my weekly usage just running for a few minutes..."*
- **nyc008:** *"After complaining about the BUG that is constantly eating up usage while I am paying for Pro, I got ANOTHER usage limit with only 9 questions and 6,756 tokens.... and then got blocked for another 5 hours - the fourth time today."*

## The LangGraph hold-out view

- **bonerfleximus:** *"They wrote 'and run it on our infrastructure' in the marketing like they think of themselves as AWS or something. I will continue using langgraph thank you."*

## Adjacent memory discussion

- **nicoloboschi:** *"Managed Agents could reduce a lot of overhead, but agents still need solid memory for recall across interactions. Hindsight is a fully open-source memory system that's worth exploring. https://github.com/vectorize-io/hindsight"*

## Humor beat

- **Calm_Hedgehog8296:** *"In celebration of this release, OpenAI has reset codex limits"* (joke, but captures the community reaction to launch day)

## OpenAI's response pattern

Adjacent reaction: API-only launch is a hint that Anthropic's direction is **B2B first**, which matches the Working_Result_1343 comment: *"They are after B2B more then B2C."*

## What to do with this

1. **Read the blog** (`claude.com/blog/claude-managed-agents`) before committing more investment to any third-party multi-agent framework for production workloads.
2. **Try the quickstart** on a small production-relevant scenario.
3. **Verify delegation visibility** — ask the API what it routed where and why.
4. **Compare against your current orchestration** on context-continuity and recovery-from-failure benchmarks.

## Related Playbook pages

- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — full reference including the structural-advantage analysis
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) — SR 11-7 / EU AI Act considerations for deploying agent pipelines to regulated verticals
- [BMad Autonomous Development]({{ site.baseurl }}/docs/bmad/) — a third-party orchestration pattern worth comparing against
