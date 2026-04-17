---
title: April 2026 Briefing
nav_order: 0
---
# AI Engineering Briefing — April 2026

**Author:** Alex O'Reilly, Force Information Systems
**Date:** 17 April 2026
**Length:** ~20-minute read

---

## Why this exists

Over the past two weeks the AI-assisted development space moved enough that a summary email wasn't enough. This briefing covers **what shipped, what matters, and what you should do about it** — with enough technical depth for an engineering audience but without the raw research-trail of the source digest (69 primary items across Medium, Reddit, Forbes, and vendor announcements).

Target audience: engineering leaders inside Harris and Constellation companies who need to make model-selection, tooling, and architecture decisions in the next 30 days.

### How to read this

Three complementary layers across the Playbook:

- **This briefing** (20 min) — what to do in the next 30 days
- **[News & Research]({{ site.baseurl }}/docs/news/)** (39 pages) — per-article deep reads of every source cited below. Each page has headline → key takeaways → full notes → what to do → related Playbook pages
- **Reference pages** (8 pages) — full technical depth on each topic: [Opus 4.7]({{ site.baseurl }}/docs/opus-4-7/), [Cost & Observability]({{ site.baseurl }}/docs/cost-and-observability/), [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/), [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/), [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/), [Local Models]({{ site.baseurl }}/docs/local-models/), [Knowledge & Context]({{ site.baseurl }}/docs/knowledge-and-context/), [BMad Autonomous Development]({{ site.baseurl }}/docs/bmad/)

Every quote and number in this briefing traces back to a named primary source; inline links in each section go to the corresponding News page for full context.

---

## Executive summary

1. **Claude Opus 4.7 shipped** on 16 April. It's a *behavioural* upgrade, not a capability upgrade — trained to behave like a senior engineer (self-verifies, pushes back, honest about gaps, literal instructions, persists through tool failures). Your existing 4.6-era prompts may behave differently.
2. **Token costs can be cut ~75% with a two-command plugin install** (`JuliusBrussee/caveman`, 13K GitHub stars). The brevity improves accuracy, backed by a 2025 paper.
3. **Production observability is now a solved problem** via Claude Code's built-in OpenTelemetry support. Docker-Compose stack is published. Expect to discover your team's actual adoption and cache-ratio patterns.
4. **OpenAI shipped an official Codex plugin for Claude Code.** 5-minute install, ~$30/month, gives you `/codex:adversarial-review` for second-opinion code review.
5. **Microsoft and Anthropic both shipped multi-model orchestration products** the same week. Microsoft's "Copilot Cowork" has a per-model attribution gap that's a problem for regulated verticals. Anthropic's "Managed Agents" has a structural advantage over LangGraph/CrewAI that's worth understanding before your next architectural decision.
6. **Gemma 4 makes local agentic coding viable** for the first time (86.4% on tau2-bench vs Gemma 3's 6.6%). Relevant for privacy-sensitive or offline workloads.
7. **SR 11-7 + EU AI Act Article 12** (effective 2 August 2026) create a compliance problem for any regulated Harris vertical that deploys an opaque multi-model pipeline without per-model attribution in audit logs.
8. **Autonomous overnight sprint execution is real and installable** — `/bad` (BMad Autonomous Development) coordinates dependency-graph-parallelised stories through git worktrees with self-healing CI.

Everything in this briefing is actionable in the next 30 days if you want it to be. The rest of the document is the "how."

---

## 1. Claude Opus 4.7 — the behavioural release

**Released:** 16 April 2026. Available across Claude products, the API (`claude-opus-4-7`), Amazon Bedrock, Google Cloud Vertex AI, and Microsoft Foundry. **Zero migration friction for Harris Azure tenants.**

**Pricing:** Per-token price unchanged at $5 / $25 per million input/output. **Tokenizer shifted — same input now maps to 1.0–1.35× more tokens depending on content.** Real bills will shift even though the rate card didn't.

> **Deep reads:** [Opus 4.7 — the behavioural release]({{ site.baseurl }}/docs/news/opus-4-7-behavioral-release/) (Rezvani) · [Opus 4.7 punishes bad prompting]({{ site.baseurl }}/docs/news/opus-4-7-punishes-bad-prompting/) (Njenga) · [Launch-day community reactions]({{ site.baseurl }}/docs/news/opus-4-7-reddit-reactions/)

### The five behavioural patterns

Anthropic published 28 enterprise customer testimonials (Stripe, Replit, Cognition, Harvey, Hex, Vercel, Notion, GitHub, iGenius, Ramp, Genspark, and others). [Reza Rezvani's analysis]({{ site.baseurl }}/docs/news/opus-4-7-behavioral-release/) distils them into five recurring patterns:

1. **Self-verifies before reporting back.** Vercel's Joe Haddad reports 4.7 "does proofs on systems code before starting work." iGenius's Sean Ward watched 4.7 autonomously build a Rust TTS engine and design its own validation loop.
2. **Honest about missing data.** Hex CTO: 4.7 "correctly reports when data is missing instead of providing plausible-but-incorrect fallbacks." For finance, legal, and healthcare this is the critical shift.
3. **Pushes back when you're wrong.** Independent CodeRabbit analysis of 100 PR reviews measured **77.6% assertiveness, 16.5% hedging**. Imperatives replace tentative suggestions.
4. **Literal instruction following.** Anthropic's own warning: "prompts written for earlier models can sometimes now produce unexpected results." Re-test everything before migrating.
5. **Persists through tool failures.** Notion reports +14% over 4.6 at fewer tokens and 1/3 the tool errors. Cognition's CEO: Devin now works coherently for hours.

### Benchmark deltas

| Metric | 4.6 | 4.7 |
|---|---|---|
| CursorBench | 58% | **70%** |
| Rakuten-SWE-Bench | baseline | **3× production tasks** |
| Databricks OfficeQA Pro | baseline | **21% fewer errors** |
| Harvey BigLaw Bench (high effort) | baseline | **90.9% substantive** |
| Image resolution | ~0.8 MP | **~3.75 MP** (3×) |
| Knowledge cutoff | May 2025 | **Jan 2025** (regression) |

The knowledge-cutoff regression is unexplained. If your team relies on post-Jan-2025 library awareness, factor this into model routing.

### New capabilities in Claude Code

- **`xhigh` effort level** — new tier between `high` and `max`, **now default across all Claude Code plans**. Defaults cost more tokens than 4.6 defaults.
- **`/ultrareview`** slash command — dedicated review session, 3 free for Pro/Max.
- **Auto mode extended to Max** — Claude makes permission decisions during agentic runs.
- **Task budgets (public beta)** — guide how Claude spends tokens across a longer run.
- **1M context variant** — invoke with `/model claude-opus-4-7[1m]`.

### Cybersecurity safeguards — important for security teams

Opus 4.7 is the **first Anthropic model shipping with safeguards detecting and blocking requests tied to prohibited or high-risk cybersecurity uses.** Legitimate security work (vulnerability research, penetration testing, red-teaming) will hit silent refusals unless the user has access through Anthropic's **Cyber Verification Program**.

If you run an internal security or red-team function at Harris:
- Inventory workflows using Claude for security research before upgrading
- Apply for Cyber Verification Program at claude.com
- Document which workflows require verified access for your compliance team

### Field reports worth knowing

- **Usage-limit burn is dramatically higher.** Community reports of Max-plan users hitting 70%+ of 5-hour limits after two prompts. `xhigh` default + 1.0-1.35× tokenizer + more thinking at higher effort compound.
- **System-reminder leak.** Anthropic's per-file-read malware-check reminder leaks into visible output on code-analysis sessions ("This file is clearly not malware — it's a standard Vue 3 component…"). A real token tax worth noticing.
- **"Car wash test" regressions** reported by community testers.
- **Model-identification bug** — some early testers found 4.7 claiming "4.6 doesn't exist, did you mean 4.5?" Resolved for most users within 24 hours.

### Migration checklist

Before you ship 4.7 to production:

1. **Re-test existing prompts** on real traffic. Literal interpretation changes output.
2. **Measure token cost** on real traffic. The 1.0–1.35× tokenizer shift is content-dependent — measure, don't assume.
3. **Audit verification layers.** Some validation built around 4.6 is now redundant (model self-verifies); some still matters (domain requires belt-and-braces). Table:

| Check exists because… | Keep under 4.7? |
|---|---|
| Model was unreliable and hallucinated fallbacks | Probably redundant |
| Regulator requires documented validation | Keep |
| Cross-system data dependencies need reconciliation | Keep |
| We assumed the model wouldn't surface inconsistency itself | Test — may now be redundant |

---

## 2. Cost optimisation — two levers

There are now two complementary techniques for controlling Claude Code spend. Combined, expect **50–75% reduction** in token consumption.

> **Deep reads:** [Cut Claude Code's output tokens by 75%]({{ site.baseurl }}/docs/news/caveman-75-percent-tokens/) (Dunlop) · [The New Claude Code Monitoring]({{ site.baseurl }}/docs/news/claude-code-monitoring/) (Rezvani) · [Graperoot "178x" — the honest reframe]({{ site.baseurl }}/docs/news/graperoot-178x/)

### Lever 1: Output compression — the `caveman` plugin

[Alex Dunlop measured it directly]({{ site.baseurl }}/docs/news/caveman-75-percent-tokens/). Same bug, same fix:
- **Default Claude Code:** 1,252 tokens
- **With `/caveman`:** 410 tokens

The ~800-token difference is filler: "Certainly," "Sure, I'd be happy to help with that," "The issue you're experiencing is most likely caused by…"

Install (two commands):
```
claude plugin marketplace add JuliusBrussee/caveman
claude plugin install caveman@caveman
```

Activate with `/caveman`. Three modes: `lite` / `full` (default) / `ultra`.

A companion `caveman-compress` rewrites CLAUDE.md files — reported **~45% savings on every session load**.

**The accuracy story is the important bit.** The 2025 paper *"Brevity Constraints Reverse Performance Hierarchies in Language Models"* finds that **brief responses improve accuracy by 26% on benchmarks**. Verbose isn't smarter; it's just more expensive.

### Lever 2: Observability — OpenTelemetry stack

Claude Code ships with OpenTelemetry instrumentation built in but **opt-in and off by default.** Turn it on with:

```
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_ENDPOINT=http://collector.your-company.com:4317
```

Reza Rezvani published a production-ready Docker Compose stack (OTel Collector + Prometheus + Grafana). For small-team pilots, Grafana Cloud's free tier accepts OTLP directly — skip the collector entirely.

The 8 metrics ranked by operational value:

**Track from day one:**
1. `claude_code.cost.usage` (by `model`) — catches teams running Sonnet where Haiku would suffice
2. `claude_code.token.usage` (by `type`: input/output/cache_read/cache_creation) — **cache-read ratio is the single best indicator of configuration health**
3. `claude_code.active_time.total` — Claude-working vs developer-waiting

**After baseline:**
4. `claude_code.session.count` per user — real adoption vs self-reported
5. `claude_code.commit.count` + `pull_request.count` — connect usage to output
6. `claude_code.code_edit_tool.decision` — accept/reject ratio reveals CLAUDE.md quality

### What the telemetry revealed on Rezvani's 7-person team

- **3 of 7 engineers got 60%+ cache-read ratios; 4 were below 15%.** Same codebase, same CLAUDE.md — only difference was prompt structure. Invisible without telemetry.
- **2 engineers generated 80% of sessions; 3 had essentially stopped** after month one. Manager gut feel said the team was using Claude Code daily. The data said otherwise.

This is the kind of signal you can't get any other way. Running the dashboard for two weeks will tell you the truth about adoption and spend.

### Traces (beta) — TRACEPARENT propagation

`CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1` + `OTEL_TRACES_EXPORTER=otlp` enables distributed tracing. Every Bash subprocess Claude Code runs **receives a TRACEPARENT environment variable with W3C trace context.** Subprocess spans automatically attach to the parent trace — end-to-end visibility from prompt to CI pipeline.

For Claude Code action in CI/CD this answers: *"that automated PR review took 45 seconds — where did the time go?"*

---

## 3. Multi-model orchestration — three products, one week

Three separate product launches in early April 2026 converged on the same architectural question: **when you have multiple AI models, how do you orchestrate them?**

> **Deep reads:** [I Ran Codex and Claude Side by Side]({{ site.baseurl }}/docs/news/codex-claude-side-by-side/) (Liu) · [Anthropic Managed Agents launch]({{ site.baseurl }}/docs/news/managed-agents-launch/) · [Building a first Managed Agent]({{ site.baseurl }}/docs/news/first-managed-agent/) (Njenga) · [The Orchestrator Was Missing]({{ site.baseurl }}/docs/news/orchestrator-was-missing/) (Rezvani)

### OpenAI Codex plugin for Claude Code (30 March 2026)

Official OpenAI release. Repo: `github.com/openai/codex-plugin-cc`. Not a fork — OpenAI publishing a plugin that runs Codex inside their direct competitor's tool.

Install (5 minutes):
```bash
npm install -g @openai/codex
codex login
# inside claude code:
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/codex:setup
```

Cost: ~$0.02 per call at GPT-5.4 pricing ($2.50/$15 per million). 50 calls/day ≈ $30/month.

Three commands worth knowing:

| Command | When to use |
|---|---|
| `/codex:adversarial-review` | Before merging anything non-trivial |
| `/codex:rescue [task]` | Background task hand-off — keeps your Claude context |
| `/codex:result` | Retrieve the async result |

**The loop-breaker heuristic** (community practice, validated across multiple sources): when Opus gets stuck in a loop, hand the problem to Codex. Opus overthinks; Codex pinpoints. The plugin makes this a one-command move.

### Anthropic Managed Agents (8 April 2026, public beta)

API-only launch. Named customers: **Notion, Sentry, Rakuten, Asana, Vibecode.** Rakuten also appeared in Opus 4.7's SWE-Bench 3× claim — suggests they're running a deep Anthropic-integrated stack worth studying.

The technical argument from the launch thread (Soft_Match5737):

> "The key advantage of first-party managed agents over CrewAI/AutoGen/LangGraph is **context continuity**. Third-party frameworks shuttle messages between isolated API calls, which means every agent handoff loses the implicit reasoning state. When Anthropic controls both the orchestration and the model, they can maintain internal representations across agent boundaries without serialising everything to text."

If that structural claim holds up in practice, it's a real efficiency edge over any third-party orchestration framework — including the OMC stack you may be building on.

**Worth reading the blog and trying the quickstart before committing further investment to any third-party multi-agent framework for production workloads.** Links:
- https://platform.claude.com/workspaces/default/agent-quickstart
- https://claude.com/blog/claude-managed-agents

### Microsoft Copilot Cowork (30 March 2026)

Two multi-model architectures inside Outlook / Teams / Excel for M365 Frontier-tier customers.

- **Critique (sequential)** — GPT drafts, Claude audits, user sees only final reviewed output. Clean UX, **opaque per-model attribution.**
- **Model Council (parallel)** — GPT and Claude each produce an independent report, a judge model synthesises showing agreements and divergences. **Transparent.**

The benchmark marketing — 13.8% DRACO win — is worth being skeptical about: the benchmark was created by Perplexity (Microsoft's competitor), Microsoft ran the tests, and GPT-5.2 (same vendor) was the judge. No independent replications.

Commercial context: Microsoft stock fell 23% in Q1 2026 — worst quarter since 2008. Only 3.3% of 450M M365 subscribers pay for Copilot. **E7 bundle at $99/seat (1 May 2026)** — M365 E5 + Copilot + Agent 365 + Entra Suite — is the monetisation vehicle; Cowork multi-model features justify the price jump.

---

## 4. Regulated AI — the compliance problem nobody's writing about

For any Harris / Constellation vertical touching regulated work (financial services, healthcare, utilities, public sector), Critique's attribution gap is the issue to raise before deployment.

> **Deep reads:** [I Ran Codex and Claude Side by Side]({{ site.baseurl }}/docs/news/codex-claude-side-by-side/) — Liu's bank-employee analysis of the SR 11-7 attribution gap · [Claude Mythos preview]({{ site.baseurl }}/docs/news/claude-mythos-preview/) · [Glasswing & Claude Mythos for CTOs]({{ site.baseurl }}/docs/news/glasswing-mythos/)

### SR 11-7 (US Federal Reserve)

Applies to every model a bank uses in a consequential decision. Requires:

- Model identification (you must know which models produced which claim)
- Independent validation per model
- Documented limitations per model
- Ongoing monitoring
- **No outsourced accountability** — using a vendor does not transfer your bank's regulatory responsibility

The OCC, Fed, and FDIC are actively applying SR 11-7 principles to generative AI deployments. A Critique-style pipeline where the bank cannot identify which GPT and Claude versions produced a given claim has a material compliance gap.

### EU AI Act Article 12 (effective 2 August 2026)

Requires **automatic, event-level logs with traceability** for high-risk AI systems. Annex III classifies as high-risk:

- Credit scoring
- AML / fraud detection
- Loan approval
- KYC / identity verification
- Many HR, insurance, and public-sector use cases

Microsoft's current M365 audit logging is who-ran-what-query-when. **Not the same as per-model attribution per inference call.** Whether E7 customers can get model-level logs is a question Microsoft has not publicly answered.

### The three vendor questions

Put these in writing on every vendor call for Cowork (or any similar multi-model enterprise product):

1. **Which model versions are in the Critique pipeline right now, and will you notify us proactively when either model is updated?**
2. **Do customers at our plan tier receive per-model attribution in audit logs, or only aggregate platform query logs?**
3. **How does your documentation support our SR 11-7 model inventory and EU AI Act Article 12 traceability obligations for the multi-model feature specifically?**

If the answers are vague or deferred, that is the answer. It doesn't mean don't deploy — it means don't deploy the opaque pipeline for high-risk AI use cases until the documentation exists. Use Model Council, Anthropic Managed Agents with explicit multi-model visibility, or your own transparent multi-model pattern in the meantime.

---

## 5. Prompt discipline — the Cialdini playbook for LLMs

[Rick Hightower's April 2026 analysis]({{ site.baseurl }}/docs/news/superpowers-cialdini/) lands on a finding worth internalising: **LLMs don't just hallucinate — they rationalise, cut corners, and abandon plans under pressure, in patterns measurably similar to tired human developers.**

> **Deep read:** [Superpowers: Cialdini's Psychology Hack for LLMs]({{ site.baseurl }}/docs/news/superpowers-cialdini/)

### The Wharton study

July 2025, co-authored by Robert Cialdini himself. Across **28,000 conversations** with GPT-4o-mini:

| Condition | Compliance rate |
|---|---|
| Baseline | 33.3% |
| With persuasion principles | **72.0%** |
| Commitment principle (foot-in-the-door) | **100%** (from 10%) |

Authority claims alone lifted compliance by **65%** on requests the AI would normally refuse.

### The practical translation — four principles

1. **Authority** — replace "it would be good to" with "You MUST" and "This is not negotiable."
2. **Commitment** — force the agent to state its plan before acting. Once stated, it's committed.
3. **Social proof** — invoke "standard practice" or "production-grade requires" to activate the model's pattern-match against professional norms.
4. **Scarcity (inverted)** — use adversarial pressure-tests to verify the agent won't abandon discipline under urgency.

### The key innovation — rationalisation tables

Catalog the specific excuses your agent generates when it wants to cut a corner. Pair each with a pre-written rebuttal.

```markdown
## Common Rationalisations (Do Not Fall for These)

| If you think... | The reality is... |
|---|---|
| "This change is too small to test" | Small changes cause big outages. Test it. |
| "I'll fix the linting later" | Later never comes. Fix it now. |
| "The existing tests cover this" | Verify that claim. Run them. Check coverage. |
| "This is just a config change" | Config changes cause more outages than code changes. Test it. |
```

This is more potent than it looks because Opus 4.7's literal instruction following amplifies both the authority and commitment effects. Weak, suggestion-based CLAUDE.md files produce noticeably worse output on 4.7 than on 4.6. **The wording change from "should" to "MUST" is a free upgrade on every prompt your team runs.**

### Action item

During the 4.7 migration window, audit every CLAUDE.md across your projects. Replace suggestion-language with authority-language. Add rationalisation tables for your agents' top 3 excuses. Version and iterate.

---

## 6. Local models — Gemma 4 is viable

**Gemma 4 scores 86.4% on the tau2-bench function-calling benchmark.** Gemma 3 scored 6.6%. The gap that makes local agentic coding practical.

> **Deep reads:** [I ran Gemma 4 as a local model in Codex CLI]({{ site.baseurl }}/docs/news/gemma-4-local-codex/) (Vaughan) · [Gemma 4 — Google's open-source release]({{ site.baseurl }}/docs/news/gemma-4-release/) (Njenga)

Apache 2.0 licensed, 256K context, self-hostable on Azure ML or on-prem.

### When it's worth it

- **Privacy-sensitive workloads** — codebases that can't leave the machine. Especially relevant for Centurion (banking) and any regulated Constellation vertical.
- **Cost-sensitive iteration loops** — multiple parallel sessions add up on cloud; local is free after hardware.
- **Resilience against cloud outages / pricing changes**

### Setup (24 GB Apple Silicon)

**Do not use Ollama on Apple Silicon with Gemma 4 as of April 2026.** v0.20.3 has a streaming bug that routes tool-calls to the `reasoning` field and a Flash Attention freeze on prompts >500 tokens (Codex CLI's system prompt is ~27,000 tokens).

Use llama.cpp:

```bash
brew install llama.cpp
llama-server \
  -m /path/to/gemma-4-26B-A4B-it-Q4_K_M.gguf \
  --port 1234 -ngl 99 -c 32768 -np 1 --jinja \
  -ctk q8_0 -ctv q8_0
```

### Setup (NVIDIA)

**Ollama v0.20.5 works.** vLLM fails (PyTorch ABI mismatch on Blackwell). llama.cpp from source compiles but Codex CLI's wire_api rejects it.

```bash
ollama pull gemma4:31b
codex --oss -m gemma4:31b
```

### Real-world performance (Vaughan's same-task benchmark)

| Config | Passes | Time | Tool calls |
|---|---|---|---|
| GPT-5.4 cloud | 5/5 first try | 65 s | — |
| GB10 31B Dense | 5/5 first try | 7 min | 3 |
| Mac 26B MoE | 5/5 eventually | 4m 42s | 10 |

Surprise finding: **the Mac generates tokens 5.1× faster than the GB10** despite identical memory bandwidth — MoE sparse activation dominates memory-bandwidth-limited generation. But raw speed doesn't matter: the Mac's 5.1× speed advantage only made it 30% faster end-to-end because the speed went into **retries**. **First-pass reliability matters more than raw throughput for agentic work.**

### The hybrid workflow

`codex --profile local` for iteration and privacy-sensitive work. Default cloud for anything complex. Codex CLI's profile system makes switching a single flag.

---

## 7. CLI vs MCP — choose per integration, not per system

The most useful architectural insight from the April 2026 research is [Reza Rezvani's per-integration decision framework]({{ site.baseurl }}/docs/news/cli-vs-mcp/). After 14 months running both in production, his team's split is roughly **70/30 CLI/MCP** — not by philosophy, by triage.

> **Deep read:** [The CLI vs MCP Debate Is Asking the Wrong Question]({{ site.baseurl }}/docs/news/cli-vs-mcp/) (Rezvani)

### What broke at MCP-only

- Six MCP servers loaded **~48,000 tokens of tool schemas** before the user typed a character
- On 200K context that's 24% consumed by plumbing; on 128K, 37.5%
- Context isn't storage — it's attention. Multi-step reasoning degraded visibly

### The data (5-workflow controlled comparison)

| Metric | MCP-only | Hybrid (CLI exec + MCP reads) |
|---|---|---|
| Median tokens/workflow | 67,200 | 23,400 |
| Completion rate | 74% | 96% |
| Multi-step reasoning failures | 31% | 8% |
| Avg completion time | 47 s | 19 s |

### Three factors for the right transport

1. **Where does the tool run?** Local → CLI. Remote infra → depends.
2. **How does it authenticate?** Ambient credentials → CLI. Delegated OAuth multi-tenant → MCP.
3. **What does the workflow look like?** Single-tenant dev automation → CLI overwhelmingly. Multi-tenant production acting on behalf of customers → MCP governance.

### Production split (Rezvani's team)

- **CLI:** git, file operations, builds, tests, deploys
- **MCP:** Slack messaging, SaaS API queries, services with no CLI (Salesforce, Workday, ServiceNow)

### What both camps get wrong

- **CLI camp:** assumes single-dev security scales to multi-tenant (it doesn't); ignores that most SaaS services don't have CLIs and never will
- **MCP camp:** dismisses token overhead as "price of admission" — **48K of plumbing lobotomises the agent's attention**; lacks native composability (can't pipe one MCP tool's output into another; Unix solved this decades ago)

**The real leverage is agent-native tool interface design** — machine-readable output by default, schema introspection at runtime, input validation for agent-specific mistakes, dry-run modes.

---

## 8. Knowledge & context — Karpathy's "LLM Wiki"

Andrej Karpathy dropped a GitHub Gist titled simply "LLM Wiki" in April. It's not an app or a library — it's a design pattern for putting **an LLM-maintained, compounding layer of markdown files between you and your raw source material.**

> **Deep read:** [Why Karpathy's "LLM Wiki" is the Future]({{ site.baseurl }}/docs/news/karpathy-llm-wiki/) (evoailabs)

### Why this matters

- **RAG has no memory of prior questions.** Ask the same compound question tomorrow — it redoes the synthesis from scratch.
- **Human-maintained wikis decay** because bookkeeping burden grows faster than value.
- **Karpathy's pattern inverts both** — the LLM does the grunt work of reading, extracting, cross-referencing.

"Obsidian is the IDE, the LLM is the programmer, the wiki is the codebase."

### Three operations

- **Ingest** — drop file in raw/, agent writes summary + updates 10-15 concept pages + adds backlinks
- **Query** — agent reads index.md, navigates to relevant pages, answers; new insights from chat get filed back
- **Lint** — periodic health-check for broken links, stale claims, contradictions, orphan pages

### The ecosystem worth knowing

- **Waykee Cortex** — hierarchical team knowledge; dual-inheritance of Knowledge + Work layers
- **Sage-Wiki** — treats LLM as a compiler; typed-entity system prevents duplicates
- **Thinking-MCP** — captures *how you think*, not factual data; node decay mirrors a live human brain
- **ELF** — scientific research; base-delta protocol for incremental experiments
- **qmd** (by Shopify CEO Tobi Lütke) — local BM25 + vector hybrid search with MCP server

### What to do with this

For any Harris internal knowledge base (customer support, engineering onboarding, compliance references) — this is the right architecture. Replacing or augmenting Notion/Confluence with an LLM-maintained wiki is practical today. The "new team members instantly browse an up-to-date wiki nobody manually wrote" use case is directly applicable to FIS customer support and onboarding.

---

## 9. Autonomous overnight development — `/bad`

**`/bad` (BMad Autonomous Development)** is a coordinator-only skill that takes over the moment your planning is done and runs sprint execution autonomously.

> **Deep read:** [/bad: BMad Autonomous Development]({{ site.baseurl }}/docs/news/bad-autonomous-sprint/)

GitHub: `stephenleo/bmad-autonomous-development`
Install: `npx skills add https://github.com/stephenleo/bmad-autonomous-development` (BMAD must already be installed)
Invoke: `/bad` in Claude Code.

### Architecture

1. **Dependency mapping** — builds a graph from `sprint-status.yml` to identify parallelisable stories
2. **Isolated execution** — each story runs in its own **git worktree**, preventing environment pollution
3. **4-step lifecycle per task:** BMAD Create-Story → Dev-Story → Code-Review → GitHub PR
4. **Self-healing CI** — monitors CI results and reviewer comments, auto-fixes until green

Never writes code itself. Delegates every unit of work to dedicated sub-agents with fresh context windows — prevents the "context explosion" that happens when a single session stays open too long.

### Pair with

- The `caveman` plugin (above) for output compression
- The OpenTelemetry stack (above) for visibility into subagent spend
- The "loop-breaker" heuristic (above) for when a specific task jams

### When to use it

- Sprint-level execution where PRDs + stories are already written
- Maintenance backlogs of well-scoped, parallelisable tickets
- Dependency-bumping campaigns across many services
- Generated-code-heavy tasks (migrations, scaffolding)

### When not

- Exploratory or discovery work (that's the human part)
- Customer-facing changes without human PR review
- Anything touching regulatory/compliance decisions
- Projects without good CI coverage — the self-heal loop relies on signal to operate

---

## 10. The 30-day action list

If you read nothing else, do this:

1. **Install `caveman` in your Claude Code setup.** Two commands, ~75% output-token reduction. Take 5 minutes today.
2. **Turn on Claude Code telemetry for your team.** Console exporter proves the concept in 10 minutes. Stand up the Grafana Cloud free tier this week. In two weeks you'll know your actual adoption and cache-ratio picture.
3. **Upgrade to Opus 4.7 with the 3-step checklist** — re-test prompts, measure token cost on real traffic, audit which verification layers are now redundant.
4. **If you have an internal security team** doing vulnerability research or pen-testing, apply for the Cyber Verification Program **before** the 4.7 upgrade hits.
5. **Install the OpenAI Codex plugin in one Claude Code environment** to try `/codex:adversarial-review` on next week's PRs. ~$30/month.
6. **Audit every CLAUDE.md** for authority-language vs suggestion-language. Add a rationalisation table for your agents' top 3 excuses. Takes less than an hour per project.
7. **If you're evaluating Copilot Cowork** for any regulated vertical, put the three vendor questions in writing before signing.
8. **If you're building on LangGraph / CrewAI / custom multi-agent** — read the Anthropic Managed Agents blog and try the quickstart before your next architectural decision.
9. **For any privacy-sensitive codebase** (Centurion banking, regulated verticals) — stand up a Gemma 4 local-model test this quarter.
10. **Skim the Playbook** (link below) — the full technical detail for every topic above sits in a dedicated page there.

---

## Links and references

### Reference pages (full technical depth)

- [Claude Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/)
- [Cost & Observability]({{ site.baseurl }}/docs/cost-and-observability/)
- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/)
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/)
- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/)
- [Local Models]({{ site.baseurl }}/docs/local-models/)
- [Knowledge & Context]({{ site.baseurl }}/docs/knowledge-and-context/)
- [BMad Autonomous Development]({{ site.baseurl }}/docs/bmad/)

### News & Research deep reads (39 articles)

The [News & Research]({{ site.baseurl }}/docs/news/) section has a dedicated per-article page for every substantive source cited above, with thematic and chronological browsing. Each page links the primary source and the related Playbook reference pages.

Key sources linked inline in each section above:

- Reza Rezvani, [All About Claude Opus 4.7 Features]({{ site.baseurl }}/docs/news/opus-4-7-behavioral-release/) — behavioural release thesis
- Joe Njenga, [Claude Opus 4.7 Is Here]({{ site.baseurl }}/docs/news/opus-4-7-punishes-bad-prompting/) — feature breakdown
- Alex Dunlop, [I Cut Claude Code's Output Tokens by 75%]({{ site.baseurl }}/docs/news/caveman-75-percent-tokens/) — caveman plugin
- Reza Rezvani, [The New Claude Code Monitoring]({{ site.baseurl }}/docs/news/claude-code-monitoring/) — OpenTelemetry stack
- Yanli Liu, [I Ran Codex and Claude Side by Side]({{ site.baseurl }}/docs/news/codex-claude-side-by-side/) — multi-model + compliance
- Daniel Vaughan, [I ran Gemma 4 as a local model in Codex CLI]({{ site.baseurl }}/docs/news/gemma-4-local-codex/) — local setup
- Rick Hightower, [Superpowers: The Psychology Hack]({{ site.baseurl }}/docs/news/superpowers-cialdini/) — Cialdini prompting
- evoailabs, [Why Karpathy's "LLM Wiki" is the Future]({{ site.baseurl }}/docs/news/karpathy-llm-wiki/)
- Reza Rezvani, [The CLI vs MCP Debate Is Asking the Wrong Question]({{ site.baseurl }}/docs/news/cli-vs-mcp/)
- Anthropic, [Introducing Claude Managed Agents]({{ site.baseurl }}/docs/news/managed-agents-launch/) — public beta

**Contact:** Alex O'Reilly, Force Information Systems, aoreilly@harriscomputer.com

---

*Generated by Claude Opus 4.7 via oh-my-claudecode. The research trail for this briefing spans 69 research items across Medium, Reddit, Forbes, and vendor announcements, consolidated into the [source digest](./digest.md) (704 lines).*
