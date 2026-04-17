---
title: Claude Code /ultraplan launched
parent: Claude Code Features & Updates
grand_parent: News & Research
nav_order: 3
permalink: /docs/news/ultraplan-launched/
---
# Claude Code Ultraplan Launched: I Just Tested It (And It's Better Than It Looks)

**Source:** Joe Njenga, [Claude Code Ultraplan Launched: I Just Tested It](https://medium.com/@joe.njenga/claude-code-ultraplan-launched-i-just-tested-it-and-its-better-than-it-looks-21a628332e97) (Medium, 2026-04-04)

## Key takeaways

- **`/ultraplan`** is Claude Code's built-in planning mode.
- Njenga's verdict: **"Better than it looks"** — tested and found genuinely useful, not a marketing feature.
- Complements `/ultrareview` (shipped with Opus 4.7) — plan first with `/ultraplan`, review before merge with `/ultrareview`.
- Fits the broader "effort as a dial" pattern (see [Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/)) where reasoning depth is now a per-task choice.

## What `/ultraplan` does

Claude Code spins up a dedicated planning session — reads your request, drafts an implementation plan, surfaces assumptions, and lets you iterate on the plan before any code is written. Distinct from just "thinking more" in a regular session because it produces a structured plan artefact you can review, edit, or reject entirely.

## Njenga's test

His overall verdict: **"Better than it looks."** Initially skeptical, found that for non-trivial work the planning step produced materially better output than jumping straight to implementation.

## Where it fits

A spectrum of intentional-slowdown patterns in Claude Code:

| Intent | Command |
|:--|:--|
| Plan before implementation | `/ultraplan` |
| Review before merge | `/ultrareview` (shipped with Opus 4.7) |
| Interactive learn-the-tool | `/powerup` |
| Autonomous sprint execution | `/bad` (via npx skills add) |

Each lets you dial how much thinking Claude Code does for a given task.

## When to use it

- Multi-file features where sequencing matters
- Refactors that touch multiple subsystems
- Anything where getting the wrong approach wastes more time than the planning cost
- Pair with Hightower's commitment-device pattern (see [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/)) — stated plans are committed plans

## Related Playbook pages

- [Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/) — `/ultrareview` is the review-side counterpart
- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — commitment devices; `/ultraplan` operationalises them
- [BMad Autonomous Development]({{ site.baseurl }}/docs/bmad/) — `/bad` is the overnight-execution complement
