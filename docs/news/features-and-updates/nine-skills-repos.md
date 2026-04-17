---
title: 9 Agent Skills Repos I Tried
parent: Claude Code Features & Updates
grand_parent: News & Research
nav_order: 9
permalink: /docs/news/nine-skills-repos/
---
# 9 Agent Skills Repos I Tried (And Now I Can't Stop Using Them)

**Source:** Joe Njenga, [9 Agent Skills Repos I Tried (And Now I Can't Stop Using Them)](https://medium.com/ai-software-engineer/9-agent-skills-repos-i-tried-and-now-i-cant-stop-using-them-e359f956137b) (Medium / AI Software Engineer, 2026-04-08)

## Key takeaways

- Curated review of nine community skill repositories for Claude Code.
- Njenga's framing: **"most look impressive until you actually try them. A handful are genuinely useful."**
- Saves you the cost of evaluating dozens of repos yourself — Njenga has already tested them.
- Pair with Rezvani's `github.com/alirezarezvani/claude-skills` (220+ skills, separate reference).

## Why this is worth reading

The Claude Code skill ecosystem is growing fast. Most community skill repos are impressive-looking but shallow on test. Njenga's article filters.

The value isn't just the list — it's the honest verdict on each. A repo that "looks amazing" but "doesn't actually work in production" is identified explicitly.

## How to use the list

1. Read Njenga's article for the nine repos + verdicts
2. Install the ones relevant to your stack (TypeScript, React, testing, etc.)
3. Compare against OMC's built-in skills if you're running OMC
4. Don't install everything — skill bloat works against you (see [skill-bloat lesson](#note-on-skill-bloat-below))

## Note on skill bloat

From CLAUDE.md lessons learned: *"More skills doesn't mean better output. Community data shows 40/47 tested skills made output worse by adding tokens and narrowing responses. Build your own for critical workflows."*

Translation: be selective. Njenga's curated nine is a better starting point than installing everything you can find.

## Complementary repos

- **`github.com/alirezarezvani/claude-skills`** — Rezvani's 220+ skills
- **`skills.sh`** — public registry (see [Skills Ecosystem]({{ site.baseurl }}/docs/skills-ecosystem/))
- **OMC's built-in skill library** — if you're running oh-my-claudecode

## Related Playbook pages

- [Skills Ecosystem]({{ site.baseurl }}/docs/skills-ecosystem/) — the registry + install reference
- [/skillify article]({{ site.baseurl }}/docs/news/skillify-hidden-skill/) — generate your own skills from patterns you already use
