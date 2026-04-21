---
title: Claude Code Routines — scheduled cloud automation
parent: Claude Code Features & Updates
grand_parent: News & Research
nav_order: 12
permalink: /docs/news/routines/
---
# Claude Code Routines — scheduled cloud automation in research preview

**Source:** Anthropic, [Introducing Routines in Claude Code](https://claude.com/blog/introducing-routines-in-claude-code) (claude.com blog, 2026-04-14). Press coverage: [9to5Mac](https://9to5mac.com/2026/04/14/anthropic-adds-repeatable-routines-feature-to-claude-code-heres-how-it-works/), [SiliconANGLE](https://siliconangle.com/2026/04/14/anthropics-claude-code-gets-automated-routines-desktop-makeover/), [VentureBeat](https://venturebeat.com/orchestration/we-tested-anthropics-redesigned-claude-code-desktop-app-and-routines-heres-what-enterprises-should-know).

## Key takeaways

- **Routines** are saved Claude Code configurations — a prompt, one or more repos, and a connector set — that run on Anthropic's web infrastructure without your machine online.
- Three trigger types: **scheduled** (cron-like), **API** (HTTP endpoint + token), **GitHub webhook** (repo events).
- Research preview. Requires Claude Code on the web enabled. Daily limits: **Pro 5 · Max 15 · Team/Enterprise 25**. Extra usage available beyond limits.
- Create via `/schedule` command in the CLI or the web UI at claude.ai/code.
- Shipped same day as a redesigned Claude Code desktop app (side-by-side sessions, integrated terminal, file editing, HTML/PDF preview).

## What a Routine is

> "A Claude Code automation you configure once — including a prompt, repo, and connectors — and then run on a schedule, from an API call, or in response to an event." — Anthropic

Runs in an isolated cloud environment against existing repo connections. No local terminal required.

## The three trigger types

| Trigger | Mechanism | Example |
|:--|:--|:--|
| **Scheduled** | Cron-like cadence (hourly / nightly / weekly) | "Every night at 2am: pull top bug from Linear, attempt fix, open draft PR" |
| **API** | POST to dedicated endpoint with auth token; returns session URL | Datadog alert → Routine triages → posts summary to Slack |
| **GitHub webhook** | Repo event (PR opened, push, etc.) | Flag PRs touching auth module; post summary to #security |

## Daily run limits

| Plan | Runs/day |
|:--|:--|
| Pro | 5 |
| Max | 15 |
| Team | 25 |
| Enterprise | 25 |

Extra usage available beyond these limits (mechanism not specified in announcement).

## How this fits the Playbook

- **Overlap with `/bad` and ralph-style loops.** `/bad` runs overnight sprints locally via git worktrees. Routines move the same pattern to Anthropic-hosted infra — no local machine needed, but no local OMC orchestration either. Pick based on whether you need OMC/BMAD tooling in the loop.
- **Complements Managed Agents.** [Managed Agents]({{ site.baseurl }}/docs/news/managed-agents-launch/) are API-first orchestration primitives. Routines are the scheduled-trigger + webhook layer on top.
- **Regulated-vertical caveat.** Cloud-hosted, scheduled, autonomous writes to repos. For SR 11-7 / EU AI Act Article 12 verticals, audit-log requirements apply — confirm per-run attribution before wiring into production pipelines. See [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/).
- **GitHub webhook trigger is the interesting one.** Matches the "autonomous code-review bot" blueprint but with Anthropic hosting the loop. Lower ops burden than the [self-hosted blueprint]({{ site.baseurl }}/docs/news/autonomous-code-review-bot/).

## Example use cases (from the announcement)

- Nightly bug triage — pull top Linear issue, attempt fix, open draft PR
- CI failure analysis overnight
- Weekly dependency audits
- Cross-language porting between branches
- PR-touching-sensitive-module flagging via webhook

## What to actually do

1. **Pilot on one low-risk scheduled job.** Nightly dependency audit or changelog generation — reversible, no production impact.
2. **Measure the daily-limit burn.** 5 runs/day on Pro is tight once you add API and webhook triggers. Team/Enterprise headroom matters if you plan fan-out.
3. **Don't auto-merge.** Keep draft PRs + human review until you've observed a few dozen runs.
4. **Compare against `/bad`** before committing. If your team already runs a BMAD autonomous pipeline, Routines duplicate the scheduler layer without the dependency-graph parallelism.
5. **Audit logging gap first.** Before any regulated use, confirm Routines emit per-run logs compatible with your EU AI Act Article 12 / SR 11-7 obligations.

## Related Playbook pages

- [/bad: BMad Autonomous Development]({{ site.baseurl }}/docs/news/bad-autonomous-sprint/) — local worktree-based overnight execution
- [Anthropic Managed Agents launch]({{ site.baseurl }}/docs/news/managed-agents-launch/) — the orchestration primitive underneath
- [Autonomous code review bot blueprint]({{ site.baseurl }}/docs/news/autonomous-code-review-bot/) — self-hosted webhook pattern
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) — attribution and audit-log requirements
- [GitHub Actions guide]({{ site.baseurl }}/docs/github-actions/) — the CI/CD side of Claude Code automation
