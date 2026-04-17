---
title: Claude Code agents — the feature I ignored for months
parent: News & Research
nav_order: 23
---
# The Claude Code Feature I Ignored for Months Was the Most Important One

**Source:** Colby McHenry, [I Never Used Claude Code Agents, Now I Can't Work Without Them](https://medium.com/@me_82386/i-never-used-claude-code-agents-now-i-cant-work-without-them-9cbb14bb3219) (Medium, 2026-04-07)

## Key takeaways

- **Agents mode** is the Claude Code feature most users overlook — lets you spawn parallel sub-agents within a session.
- McHenry ignored it for months; now says he "can't work without it."
- Different from [Agent Teams]({{ site.baseurl }}/docs/agent-teams/) — those are separate Claude Code sessions with shared task list. Agents mode runs *inside* your session.
- Different from [Anthropic Managed Agents]({{ site.baseurl }}/docs/news/managed-agents-launch/) — that's a hosted orchestration service, API-only.

## The three levels of "agents" in Claude Code — keep them straight

The community uses "agents" for at least three different things. Clarifying:

| Pattern | Runs where | Coordination |
|:--|:--|:--|
| **Agents mode (this article)** | Inside your Claude Code session | Returns summaries to parent session |
| **Agent Teams** | Separate Claude Code sessions | Shared task list + peer messaging |
| **Anthropic Managed Agents** | Anthropic's infrastructure | First-party orchestration layer |

Agents mode is the lightest-weight pattern — use it for fan-out searches, parallel exploration, independent sub-tasks that don't need their own sessions.

## When to use agents mode

- Fan-out searches across a codebase
- Parallel exploration of multiple hypotheses
- Independent sub-tasks that can run concurrently and don't need shared context
- Quick "run these three things in parallel and come back to me" workflows

## When to escalate to Agent Teams instead

- Truly parallel implementation across multiple files
- When each agent needs its own full context window
- When agents need to coordinate via shared task list / peer messaging

## When to use Managed Agents instead

- Production agent pipelines with state-management requirements
- When you want Anthropic to handle infrastructure + permissions layer
- When context-continuity across handoffs matters for efficiency

## Why this is worth reading

The delta between "didn't use agents" and "can't work without them" is evidence that a significant fraction of Claude Code users are under-using the tool simply because they haven't tried the feature. If you haven't used agents mode, spend 30 minutes with it.

## Related Playbook pages

- [Agent Teams]({{ site.baseurl }}/docs/agent-teams/) — when to escalate from in-session agents to separate-session teams
- [Anthropic Managed Agents launch]({{ site.baseurl }}/docs/news/managed-agents-launch/) — when to escalate further to the first-party service
- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — how agents fit into the broader orchestration picture
