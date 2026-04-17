---
title: Gemma 4 — Google's open-source release
parent: Models & Vendors
grand_parent: News & Research
nav_order: 13
---
# Gemma 4: Google Just Released an Open Source AI Model for Developers

**Source:** Joe Njenga, "Gemma 4: Google Just Released an Open Source AI Model for Developers" (2026-04-03). Short-URL: `medium.com/ai-software-engineer/9358c440b084`.

## Key takeaways

- **Gemma 4 is Apache 2.0** — genuinely open weights, self-hostable.
- **256K context window** — roughly competitive with paid cloud offerings.
- **Four model sizes** — fits a range of hardware from a Mac laptop to a multi-GPU workstation.
- **Native audio** support built in.
- **tau2-bench function-calling: 86.4%** (up from 6.6% in Gemma 3) — the gap that makes agentic coding practical.
- Runs well inside Claude Code; also works with Codex CLI (see [Vaughan's hands-on]({{ site.baseurl }}/docs/news/gemma-4-local-codex/)).

## Why this is the model release that matters for enterprise

Most headline model releases are cloud-only and subject to the vendor's data-use policies. Gemma 4 is Apache 2.0 — run it on your own hardware, keep your code off anyone else's server, no usage limits. For regulated verticals that's a differentiated capability, not just a cost reduction.

### What changed from Gemma 3

| Aspect | Gemma 3 | Gemma 4 |
|:--|:--|:--|
| tau2-bench function calling | 6.6% | **86.4%** |
| License | Apache 2.0 | Apache 2.0 (same) |
| Context window | 128K | **256K** |
| Native audio | No | **Yes** |
| Model sizes | 3 | 4 |

## Practical setup

For concrete setup walk-throughs see:

- **Vaughan's Codex CLI hands-on:** [I ran Gemma 4 as a local model in Codex CLI]({{ site.baseurl }}/docs/news/gemma-4-local-codex/) — full llama.cpp and Ollama configs, benchmark results, gotchas
- **Playbook reference:** [Local Models]({{ site.baseurl }}/docs/local-models/) — the hybrid cloud/local decision tree and install recipes

## Where it fits in the Harris / Constellation stack

- **FIS Centurion (banking)** — privacy-sensitive by definition. Apache 2.0 Gemma 4 on Azure ML or on-prem is a genuinely differentiated deployment model for regulated banking customers.
- **Public sector / utilities** — same argument. Data-residency requirements become easier when inference is local.
- **Harris Azure tenants** — self-host on Azure ML as a compliance-clean alternative to OpenAI / Anthropic API endpoints for specific workloads.
- **NanoClaw (if cost-sensitive)** — for iteration loops where privacy doesn't matter, Gemma 4 locally replaces a non-trivial fraction of API spend.

## Related Playbook pages

- [Local Models]({{ site.baseurl }}/docs/local-models/) — full setup reference
- [I ran Gemma 4 as a local model in Codex CLI]({{ site.baseurl }}/docs/news/gemma-4-local-codex/) — Vaughan's hands-on benchmark
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) — when local is a compliance win
