---
title: /team-onboarding — fixes team setup chaos
parent: Claude Code Features & Updates
grand_parent: News & Research
nav_order: 1
permalink: /docs/news/team-onboarding/
---
# I Tested Claude Code /team-onboarding (And It Fixes Team Setup Chaos)

**Source:** Joe Njenga, "I Tested Claude Code /team-onboarding" forwarded to Alex 2026-04-13. Short-URL: `medium.com/p/1111b15f2f18`.

## Key takeaways

- New `/team-onboarding` slash command addresses the real pain of onboarding new engineers to Claude Code workflows.
- Walks developers through the specific questions: which CLAUDE.md instructions apply, which MCPs to connect, how prompts are structured for the codebase.
- Reduces onboarding from weeks of trial-and-error to a structured checklist.
- Pair with the [Playbook onboarding section]({{ site.baseurl }}/onboarding/) for a complete setup.

## The problem

Onboarding new engineers to Claude Code is harder than onboarding to VS Code or JetBrains. They need to learn:

- What's in the project's CLAUDE.md (and why)
- Which slash commands the team uses
- Which MCP servers are connected
- How the team's hooks behave
- What's local vs shared config
- What prompts work for this codebase

Before `/team-onboarding`, this was tribal knowledge. New engineers picked it up by asking senior engineers repeatedly.

## What `/team-onboarding` does

Walks the new developer through a structured checklist interactively. The command guides them through each harness layer, checks that their local config matches the team's shared config, and flags anything missing.

## When to use it

- Every time a new engineer joins any of your Claude Code-using projects
- At the start of a new project using Claude Code for the first time
- After a major CLAUDE.md or skill-library refactor, as a "re-onboarding" for the whole team

## Pair with

- The [Playbook's `onboarding/` section]({{ site.baseurl }}/onboarding/) — the structured Day 0 → productive path
- Any team-scoped hooks — run them in the first session so the new engineer sees what deterministic enforcement looks like

## Regenerated with real 30-day usage

The Playbook ships a [Team Onboarding template]({{ site.baseurl }}/templates/ONBOARDING-TEAM/) pre-filled with Alex's actual past-30-day usage: 2,228 sessions across 320+ repos, top commands `/mcp` `/effort` `/bad` (10× each), top MCPs `computer-use` + `chrome-devtools`. See the full field report in [30-Day Usage Insights]({{ site.baseurl }}/docs/usage-insights/) — numbers in the template are reproducible with the commands on that page against your own `~/.claude/projects/` logs.

## Related Playbook pages

- [Team Onboarding template]({{ site.baseurl }}/templates/ONBOARDING-TEAM/) — the copy-paste guide with real usage stats
- [30-Day Usage Insights]({{ site.baseurl }}/docs/usage-insights/) — what actually gets used across 2,228 sessions
- [Onboarding]({{ site.baseurl }}/onboarding/) — Day 0 to productive path
- [Agent Harness]({{ site.baseurl }}/docs/news/agent-harness/) — the concept this command operationalises
- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — hardening the CLAUDE.md files the new engineer will read
