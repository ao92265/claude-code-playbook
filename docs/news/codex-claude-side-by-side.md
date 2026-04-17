---
title: I Ran Codex and Claude Side by Side
parent: Multi-Model Orchestration
grand_parent: News & Research
nav_order: 1
---
# I Ran Codex and Claude Side by Side. Here's What I Found.

**Source:** Yanli Liu, [I Ran Codex and Claude Side by Side. Here's What I Found.](https://medium.com/ai-advances/i-ran-codex-and-claude-side-by-side-heres-what-i-found-ee16ea991838) (Medium / AI Advances, 2026-04-13, 12 min read)

## Key takeaways

- **2026-03-30:** OpenAI shipped an **official plugin** for Claude Code (`github.com/openai/codex-plugin-cc`). Not a fork — OpenAI maintaining a plugin that extends their direct competitor's tool.
- **5-minute install, ~$0.02 per `/codex:rescue` call, ~$30/month at 50 calls/day.**
- Concrete demo: Claude self-reviewed its own code as "looks correct." Codex's adversarial review flagged three real issues Claude missed.
- Microsoft shipped **Copilot Cowork** the same day — two multi-model architectures (Critique sequential, Model Council parallel).
- **Compliance gap:** Critique hides per-model attribution. For SR 11-7 banks and EU AI Act Article 12 high-risk systems, this is a problem.
- Three vendor questions you should put on every Cowork sales call.
- Microsoft's 13.8% DRACO benchmark was run on Perplexity's benchmark, by Microsoft, with GPT-5.2 (same vendor) as judge. Not yet independently replicated.

## The unexpected launch

> "On March 30, OpenAI released an official plugin for Claude Code. Not a community fork, not a hack. An official release from OpenAI, published under their own GitHub account, designed to run Codex inside their direct competitor's tool."

Business logic: developers who live in Claude Code aren't going away. Codex needs to be where developers are.

## Install (5 minutes)

```bash
npm install -g @openai/codex
codex login

# inside Claude Code:
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

Requires Node.js 18.18+, ChatGPT account (free tier works) or OpenAI API key.

## Cost

Per `/codex:rescue` call ≈ 2K input + 1K output tokens at GPT-5.4 pricing ($2.50/$15 per million) = **~$0.02/call**. 50/day = ~$1/day = ~$30/month. Free ChatGPT tier rate-limits aggressively; API key is more reliable for regular use.

## The three commands

| Command | What it does |
|:--|:--|
| `/codex:adversarial-review` | Codex reviews Claude's output. Challenges design decisions, questions assumptions, surfaces edge cases you haven't considered. |
| `/codex:rescue [task]` | Hand off a background task. Keeps your Claude context intact while Codex works async. |
| `/codex:result` | Retrieve the async result into your session. |

## The live example

Claude wrote a batch API processor:

```python
def process_batch(responses):
    results = []
    for r in responses:
        if r.status_code == 200:
            results.append(r.json()["data"])
    return results
```

**Claude's self-review:** *"Looks correct. Handles the success case, filters non-200 responses."*

**After `/codex:adversarial-review`, Codex flagged three issues Claude missed:**

1. `r.json()["data"]` raises `KeyError` if the API returns 200 without a `"data"` key — real case for partial responses.
2. No handling for `r.json()` itself failing — malformed JSON on a 200 is more common than it sounds.
3. Silent discard of non-200 responses means errors disappear — any monitoring downstream will miss failures.

> "Claude had read the same code and said it looked fine. Two models. Different answers. Both useful — but one of them was actually useful. The reason this works isn't magic. Claude and Codex have different training distributions, different fine-tuning histories, different failure modes. When they disagree, the disagreement is usually pointing at something real."

## When NOT to use it

- Small throwaway scripts — review cycle slows you down more than it helps
- Exploratory tasks — adversarial review of early drafts mostly generates noise
- Tasks where Claude's reasoning already exceeds the complexity
- Use it on: production PRs, research informing decisions, documents read by people who aren't you

## The bigger picture — Copilot Cowork

Microsoft shipped Copilot Cowork the same day (2026-03-30) inside Outlook / Teams / Excel for M365 Frontier-tier customers. **Two distinct architectures, different trade-offs.**

### Critique (sequential)

- GPT plans, retrieves, drafts with citations
- Claude audits — source reliability, report completeness, evidence grounding
- User sees only the final reviewed answer. **Intermediate draft is hidden by design.**
- DIY equivalent: `/codex:adversarial-review`

### Model Council (parallel)

- GPT and Claude each produce a complete, independent report on the same question
- A third "judge model" evaluates both outputs, generates synthesis showing **agreements, divergences, and what each found the other missed**
- Disagreements are visible
- DIY equivalent: run `/codex:rescue [question]` while Claude answers the same question in your active session, compare when both complete

> "The trade-off is transparency versus convenience. Critique gives you a clean answer. Model Council gives you the map of the disagreement. Which one you want depends on what you're doing with the output — and, as we'll see, how accountable you need to be for it."

## The benchmark scepticism

Microsoft's headline: 13.8% DRACO improvement over "nearest competitor."

- **DRACO was created by Perplexity** — Microsoft's direct competitor.
- Microsoft ran the tests themselves.
- **Judge model was GPT-5.2 — same vendor as the drafter.**
- No independent replications yet.

> "The 13.8% improvement may be real. It hasn't been verified by anyone without a stake in the outcome."

## The attribution gap — Liu's bank perspective

Liu works inside a bank. His first question wasn't "does it work?" but **"which model said what, and can I prove it to an examiner?"** The answer today: **no.**

### SR 11-7 (US Federal Reserve)

- Applies to every model used in consequential decisions
- Requires model identification + independent validation + documented limitations + ongoing monitoring
- **Outsourcing to a vendor does not transfer regulatory accountability**
- OCC, Fed, and FDIC actively applying to genAI deployments
- **Critique creates a two-model pipeline. SR 11-7 wants documentation on both.** The output doesn't tell you which GPT drafted and which Claude critiqued. If Microsoft updates either silently, you may not know.

### EU AI Act Article 12 (effective 2026-08-02)

- High-risk AI systems (credit scoring, AML/fraud, loan approval, KYC) require **automatic event-level logs with traceability**
- **Logging requirement applies to the pipeline, not just the output**
- Microsoft currently provides M365-level audit (who/what/when) — **not per-model attribution per inference call**
- Whether E7 customers can get model-level logs is a question Microsoft has not publicly answered

### Liu's scenario

> "A compliance officer uses Copilot Researcher with Critique to assess whether a specific derivative structure is permissible under CFTC guidance. The pipeline returns a confident, well-cited answer. One citation is misread; one regulatory interpretation is slightly wrong. The bank relies on it. An examiner asks six months later: which model version produced that interpretation? Was it validated under SR 11-7? What was the model's version at the time of the query? Under the current architecture, none of those questions have answers the bank can produce."

## Commercial context

- Microsoft stock fell **23% in Q1 2026** — worst quarter since 2008
- Only **3.3% of 450M M365 subscribers** pay for Copilot
- Head-to-head vs ChatGPT, users choose Copilot **18% of the time**
- **E7 bundle at $99/seat (2026-05-01)** — M365 E5 + Copilot + Agent 365 + Entra Suite — is the monetisation vehicle
- Cowork multi-model features justify the price jump

## Liu's recommendations

### If you're a developer

- Install the plugin. `/codex:adversarial-review` on next piece of work you care about.
- `/codex:rescue` for context-preserving handoffs.
- Keep a human in the loop until you know your patterns.

### If you're evaluating Copilot Cowork at a regulated institution

Three questions before go-live:

1. **Which model versions are in the Critique pipeline right now, and will you notify us proactively when either model is updated?**
2. **Do E7 customers receive per-model attribution in audit logs, or only aggregate M365 query logs?**
3. **How does your documentation support our SR 11-7 model inventory and EU AI Act Article 12 traceability obligations for the Critique feature specifically?**

If the answers are vague, that is the answer.

### If you manage model risk

Flag Critique for SR 11-7 review before it goes live. **Model Council is more defensible** — both outputs are visible, both can be documented.

## What Liu changed in his workflow

> "I also stopped treating the cases where they disagree as noise. The disagreement is usually the finding. Two frontier models reaching different conclusions on the same source material almost always means someone's making an assumption worth examining."

## Related Playbook pages

- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — full Codex plugin + Model Council pattern reference
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) — SR 11-7 and EU AI Act Article 12 in depth + the 3 vendor questions
- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — adversarial review as a TDD-for-prompts pattern
