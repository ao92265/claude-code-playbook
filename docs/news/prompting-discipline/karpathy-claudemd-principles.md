---
title: Karpathy's CLAUDE.md — what each principle really fixes
parent: Prompting & Discipline
grand_parent: News & Research
nav_order: 4
permalink: /docs/news/karpathy-claudemd-principles/
---
# Andrej Karpathy's CLAUDE.md: What Each Principle Really Fixes

**Source:** Cited in Email 08 bundle (16 sub-articles, 2026-04-13). Attached as `Andrej Karpathy's CLAUDE.md: What Each Principle Really Fixes.eml` (~58KB).

## Key takeaways

- **Goes through every principle** in Karpathy's widely-cited CLAUDE.md gist and explains the failure mode each fixes.
- Essential companion to Karpathy's actual gist: `gist.github.com/karpathy/442a6bf555914893e9891c11519de94f`
- Pair with [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) (Cialdini) and [Agent Harness]({{ site.baseurl }}/docs/news/agent-harness/) for the complete CLAUDE.md hardening playbook.

## Why principle-by-principle framing matters

Copying Karpathy's CLAUDE.md verbatim doesn't help if you don't understand *why* each line is there. The article walks through:

- Which line prevents which specific failure mode
- Why some principles matter more on Opus 4.7 (literal interpretation) than on 4.6
- How to adapt the principles to your project's specific context

## Audit your CLAUDE.md against this article

If you haven't audited your four project CLAUDE.md files (Wraith, ACT, Centurion, NanoClaw) against Karpathy's principles + this article's explanations, that's the single highest-value one-hour task in your April 2026 playbook.

## Related Playbook pages

- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — authority-language upgrade
- [Agent Harness]({{ site.baseurl }}/docs/news/agent-harness/) — CLAUDE.md's role in the harness
- [Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/) — why 4.7 amplifies CLAUDE.md quality differences
- [Templates]({{ site.baseurl }}/templates/CLAUDE/) — the Playbook's own CLAUDE.md templates
