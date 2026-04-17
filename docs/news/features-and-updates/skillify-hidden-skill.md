---
title: /skillify — the internal skill nobody knew about
parent: Claude Code Features & Updates
grand_parent: News & Research
nav_order: 4
permalink: /docs/news/skillify-hidden-skill/
---
# Claude Code Has an Internal Skill Nobody Knew About: /skillify

**Source:** David Veselý, [Claude Code Has an Internal Skill Nobody Knew About: /skillify](https://medium.com/@davidvesely.cz/claude-code-has-an-internal-skill-nobody-knew-about-skillify-915efff67f27) (Medium, 2026-04-08)

## Key takeaways

- **`/skillify` generates skill files from existing patterns in your codebase.**
- Auto-creates `.claude/skills/*/SKILL.md` entries from repeated workflows you already do.
- Solves the "I keep doing this — should make it a skill" friction loop.
- Directly relevant to OMC's skill system and to any team starting to build a shared skill library.

## The pitch

If you keep doing the same thing in Claude Code sessions — "run tests, fix failures, update changelog" for example — the "right" thing is to make it a reusable skill. Nobody does it because writing `SKILL.md` files from scratch is friction.

`/skillify` takes the workflow you just ran and generates a SKILL.md draft for you. You review, edit, and commit.

## Why this matters

- **Lowers the activation energy for skill creation.** The difference between "yeah I should make that a skill" and "I made it a skill" is usually 10 minutes of writing. `/skillify` cuts that to 2 minutes of review.
- **Useful for team skill libraries.** Once one engineer skillifies a workflow, the rest of the team can run it. Multiplier effect.
- **Complements OMC's own `skillify` skill.** If you're running OMC, you have a parallel implementation. Worth comparing the two approaches.

## Where it fits in the broader skill ecosystem

- [skills.sh registry]({{ site.baseurl }}/docs/skills-ecosystem/) — the public registry of installable skills
- [Agent Skills Repos]({{ site.baseurl }}/docs/news/nine-skills-repos/) — Joe Njenga's curated review of what's in the ecosystem
- **OMC's `/oh-my-claudecode:skillify`** — if you're running OMC, this is the parallel built-in
- Rezvani's **`github.com/alirezarezvani/claude-skills`** — 220+ skills as a reference library

## Related Playbook pages

- [Skills Ecosystem]({{ site.baseurl }}/docs/skills-ecosystem/) — the registry + install reference
- [Knowledge & Context]({{ site.baseurl }}/docs/knowledge-and-context/) — skills as a layer in the Karpathy wiki pattern
- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — skills that survive the CLI-vs-MCP boundary
