---
title: Why Karpathy's LLM Wiki is the Future
parent: News & Research
nav_order: 8
---
# Why Andrej Karpathy's "LLM Wiki" is the Future of Personal Knowledge

**Source:** evoailabs, [Why Andrej Karpathy's "LLM Wiki" is the Future of Personal Knowledge](https://medium.com/@evoailabs/why-andrej-karpathys-llm-wiki-is-the-future-of-personal-knowledge-7ac398383772) (Medium, 2026-04-06, 5 min read)

## Key takeaways

- **Karpathy dropped a GitHub Gist titled "LLM Wiki"** in April 2026 — not an app, not a library, a **design pattern** for compounding knowledge between you and raw sources.
- **"Obsidian is the IDE, the LLM is the programmer, the wiki is the codebase."**
- Three-layer architecture: raw sources (immutable) → wiki (LLM-maintained) → schema (CLAUDE.md rules).
- Three operations: **Ingest → Query → Lint.**
- Five ecosystem projects already building on the pattern: Waykee Cortex, Sage-Wiki, Thinking-MCP, ELF, qmd (by Shopify CEO Tobi Lütke).

## The problem being solved

> "RAG has a critical flaw: there is no accumulation. If you ask a complex question that requires synthesizing five different documents, the LLM has to find and piece together those fragments from scratch. If you ask a similar question tomorrow, it does the exact same work again. Nothing is built up."

> "On the flip side, humans have tried manually building linked knowledge bases for decades (e.g., the Zettelkasten method, Notion wikis, Obsidian vaults). But human-maintained wikis inevitably fail because the bookkeeping burden — updating cross-references, tagging, and noting contradictions — grows much faster than the value."

The LLM Wiki pattern inverts both. **The LLM does the grunt work; you explore and ask questions.**

## The pattern

> "Obsidian is the IDE, the LLM is the programmer, the wiki is the codebase."

### Three layers

1. **Raw sources (immutable)** — curated PDFs, articles, meeting transcripts, images. LLM reads but never modifies.
2. **The Wiki (LLM-maintained)** — directory of markdown files (summaries, concept pages, timelines). Fully maintained by the LLM.
3. **The Schema** — configuration file (CLAUDE.md, AGENTS.md, or equivalent) that tells the agent how to structure the wiki, ingest new files, format answers.

### Three operations

- **Ingest** — drop a new article into `raw/`. Agent reads it, writes a summary, updates 10–15 related concept pages with new insights, adds backlinks, logs the action.
- **Query** — ask a question. Agent reads `index.md`, navigates to the right pages, answers. New connections discovered mid-chat get filed back as new pages.
- **Lint** — periodically ask the LLM to health-check. Hunts for broken links, stale claims, contradictions, orphan pages.

## Use cases

- **Personal growth** — journal entries, health data, podcast notes → evolving structured picture of psychology and goals
- **Academic/deep research** — incrementally build an evolving thesis, link methodologies, note where researchers contradict
- **Book & hobby tracking** — chapter notes → Tolkien-style fan wiki with characters, locations, plot lines
- **Business & teams** — Slack threads, customer calls, PRs → new team members instantly browse an up-to-date internal wiki nobody manually wrote

## The ecosystem — five projects

### 1. Waykee Cortex — hierarchical team knowledge

Adds strict hierarchical inheritance (specific UI screen → module → system) and uniquely combines a **Knowledge** layer (what exists) with a **Work** layer (tasks, bugs, milestones). Issues inherit dual-context automatically.

### 2. Sage-Wiki — the pipeline approach (by xoai)

Treats the LLM less like a conversational agent, more like a **strict compiler** (similar to `make`). Five-step incremental pass: `diff → summarize → extract → write → images`. Enforces a typed-entity system (e.g., `is-a`, `contradicts`) to prevent duplicate concepts.

Link: https://x.com/xoai/status/2040936964799795503

### 3. Thinking-MCP — capturing mental models

Rather than tracking factual data, captures **how you think**. Scans conversation transcripts to map heuristics, tensions, decision-making rules. Uses **node decay** — core values persist, fleeting ideas fade over time, mirroring the live state of a human brain.

### 4. ELF (Eli's Lab Framework) — scientific research

Mixes the PARA organization method with wiki architecture. Uses a **base-delta protocol** for incremental experiments — total data traceability with minimal researcher documentation fatigue.

### 5. qmd — local markdown search (by Shopify CEO Tobi Lütke)

As wikis scale past a few hundred files, `index.md` isn't enough. qmd acts as a **local search engine over markdown files using BM25 + vector hybrid**. With an MCP server, the LLM can shell out to qmd natively to fetch information across massive personal wikis.

## The big-picture shift

> "The LLM Wiki pattern marks a fundamental maturity in how we use AI. We are moving away from treating LLMs purely as search engines or text generators, and finally starting to use them as tireless librarians and system maintainers. By shifting the workload of documentation to the AI, we finally unlock the dream of a compounding 'Second Brain' that actually takes care of itself."

## How this lands in Claude Code

For teams not on OMC:

1. Create `docs/wiki/` with `raw/`, `concepts/`, `timelines/` subfolders and an `index.md`
2. Add a skill or CLAUDE.md section defining the three operations (Ingest / Query / Lint) as explicit commands
3. When you read an article or transcript, drop it in `docs/wiki/raw/` and run `/ingest`
4. Periodically run `/lint` to catch broken links, stale claims, orphan pages

As the wiki grows past a few hundred files, consider installing `qmd` with its MCP server for faster search.

## Karpathy's original post

Link: https://x.com/karpathy/status/2040470801506541998

## Related Playbook pages

- [Knowledge & Context]({{ site.baseurl }}/docs/knowledge-and-context/) — full LLM Wiki reference
- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — the schema layer often uses Cialdini-style authority language
- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — qmd uses MCP; wiki pattern works across Claude + Codex + Gemini
