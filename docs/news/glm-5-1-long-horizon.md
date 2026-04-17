---
title: GLM-5.1 on Claude Code — long-horizon agentic coding
parent: Models & Vendors
grand_parent: News & Research
nav_order: 16
---
# I Tried GLM-5.1 on Claude Code (And Discovered Long-Horizon Agentic Coding)

**Source:** Email 08 bundle sub-article (2026-04-13).

## Key takeaways

- **GLM-5.1** — Zhipu AI's model — tested inside Claude Code.
- Author reports discovering **"long-horizon agentic coding"** capability that the Western open-weights (Gemma 4) doesn't match.
- Part of the broader signal that **Chinese AI labs are shipping capable open-weight alternatives** worth knowing about.

## Where GLM-5.1 fits vs Gemma 4

| Model | Strengths | Weaknesses |
|:--|:--|:--|
| Gemma 4 | Apache 2.0, wide adoption, solid benchmarks | Less tested on long-horizon tasks |
| GLM-5.1 | Long-horizon coding, Chinese lab's flagship | License / provenance considerations for some verticals |
| Qwen | Most-downloaded worldwide | Similar provenance considerations |

## For Harris

For regulated verticals:
- **GLM-5.1 and Qwen** raise provenance questions that Gemma 4 doesn't (Chinese origin vs US/UK origin).
- For public sector, defence, certain financial scenarios — this may limit adoption.
- For research and engineering use cases with lower compliance bar, all three are credible options.

## Related Playbook pages

- [Local Models]({{ site.baseurl }}/docs/local-models/) — setup generalises across open-weights models
- [Qwen — most downloaded]({{ site.baseurl }}/docs/news/qwen-open-source/)
- [I ran Gemma 4 in Codex CLI]({{ site.baseurl }}/docs/news/gemma-4-local-codex/)
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) — provenance compliance considerations
