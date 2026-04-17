---
title: Anthropic runs hundreds of skills — I published 235, 12 run weekly
parent: Prompting & Discipline
grand_parent: News & Research
nav_order: 5
---
# Anthropic Runs Hundreds of Skills. I Published 235. After 6 Months, Only a Dozen Actually Run Weekly.

**Source:** Reza Rezvani, [Anthropic Runs Hundreds of Skills. I Published 235. After 6 Months, Only a Dozen Actually Run Weekly.](https://alirezarezvani.medium.com/anthropic-runs-hundreds-of-skills-fa524c84025f) (Medium, 2026-04-17, 12 min read, published "just now" as of initial catalog)

## Subtitle

> "A seven-person team's field report on the Anthropic Claude Code skills playbook — what compounds, what rots, and the four categories that repay the audit."

## Key takeaways

- **Rezvani published 235 skills in 6 months. Only 12 actually run weekly.** That 235 → 12 gap is the point of the article.
- **Anthropic's own skills playbook has 9 categories.** Four of them repay the audit; the rest tend to rot.
- Skills are **folders, not files** — progressive disclosure via filesystem is the high-leverage pattern.
- **Gotchas sections are the highest-leverage content** in any skill definition.
- Field report from a 7-person engineering team's real usage.

## The frame

> "The first time, I nodded at everything. Nine categories. Skills are folders, not files. Gotchas sections are the highest-leverage content. Progressive disclosure via the filesystem. All of it matched what I have been telling my engineering team for six months. The second time, I opened a spreadsheet."

The methodology:
- **Column A:** every skill in Rezvani's public `claude-skills` repository (235 of them)
- **Column B:** each skill mapped to an Anthropic category
- **Column C:** last time the skill was actually invoked by a human or by Claude on his team

> "By the time I finished, the number I cared about was not 235. It was twelve."

## 235 skills published. 12 running weekly.

The implication: **skill bloat is real and measurable.** Most skills don't survive their first month of real use. The ones that compound have specific traits (the article enumerates these; full content requires Medium membership — currently being fetched on a signed-in profile for full transcription).

## Why this matters for Harris / Constellation

Direct application to any team running OMC, BMAD, or custom skill libraries:

1. **Audit your own skill library.** For Wraith/ACT/Centurion/NanoClaw — which skills actually get invoked weekly? Which ones are aspirational?
2. **Reduce skill bloat deliberately.** From the CLAUDE.md note on skill bloat: *"Community data shows 40/47 tested skills made output worse by adding tokens and narrowing responses."* Rezvani's 235 → 12 data point confirms at personal scale.
3. **Build your own for critical workflows** instead of importing everything you can find. Rezvani's verdict matches the CLAUDE.md lessons-learned advice.

## The four categories that repay the audit

Full list requires Medium member access; being fetched separately. Watch for update.

## Related Playbook pages

- [9 Agent Skills Repos I Tried]({{ site.baseurl }}/docs/news/nine-skills-repos/) — Njenga's curated review
- [Skills Ecosystem]({{ site.baseurl }}/docs/skills-ecosystem/) — the public registry
- [/skillify — the internal skill]({{ site.baseurl }}/docs/news/skillify-hidden-skill/) — auto-generate skills from patterns
- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — the related authority/commitment patterns

## Rezvani's skill library

Public repo: `github.com/alirezarezvani/claude-skills` — 235+ skills across multiple domains, now candidate for the audit Rezvani describes in the article itself.

*Catalog status: preview content captured; full deep-read pending Medium signed-in fetch.*
