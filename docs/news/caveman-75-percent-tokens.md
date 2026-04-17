---
title: Cut Claude Code's output tokens by 75%
parent: News & Research
nav_order: 3
---
# I Cut Claude Code's Output Tokens by 75%

**Source:** Alex Dunlop, [I Cut Claude Code's Output Tokens by 75%. Why Did Nobody Tell Me?](https://medium.com/vibe-coding/i-cut-claude-codes-output-tokens-by-75-why-did-nobody-tell-me-3275138852e2) (Medium / Vibe Coding, 2026-04-11, 4 min read)

## Key takeaways

- **Default Claude Code: 1,252 tokens. With `/caveman`: 410 tokens.** Same fix, same answer.
- **Free GitHub plugin `JuliusBrussee/caveman`** with 13,000+ stars.
- Paper-backed: *Brevity Constraints Reverse Performance Hierarchies in Language Models* finds **brief responses improve accuracy by 26%** on benchmarks.
- Companion `caveman-compress` rewrites CLAUDE.md for ~45% savings on every session load.
- Dunlop's adoption: `/caveman` on every session, replaced manual CLAUDE.md compression, rate-limit hits dropped.

## The opening line

> "Claude Code is charging you for words like 'Certainly'. Not a fix. Not code. 'Certainly', 'Sure, I'd be happy to help with that', and 'The issue you're experiencing is most likely caused by…'. We are paying for this."

## The test

Dunlop took the same Unity UI element bug. Asked Claude Code to explain it twice.

| Mode | Tokens |
|:--|:--|
| Default Claude Code | 1,252 |
| With caveman | 410 |

Same fix. Same answer. Roughly **800 extra tokens of fluff**.

## The fix — two commands

```bash
claude plugin marketplace add JuliusBrussee/caveman
claude plugin install caveman@caveman
```

Then `/caveman` in any session to activate.

## What caveman output actually looks like

**Before caveman:**
> "Sure! I'd be happy to help you with that. The issue you're experiencing is most likely caused by your authentication middleware not properly validating the token expiry. Let me take a look and suggest a fix."

**After caveman:**
> "Bug in auth middleware. Token expiry check use < not <=. Fix:"

## The accuracy surprise

Dunlop expected less tokens = worse output. He was wrong.

A paper titled *"Brevity Constraints Reverse Performance Hierarchies in Language Models"* found the opposite: **brief responses improve accuracy by 26%** on benchmarks.

> "Verbose answers aren't smarter, they are more expensive."

## Three intensity modes

| Mode | Command | What it strips |
|:--|:--|:--|
| Lite | `/caveman lite` | Trims a bit. Grammar + professional tone preserved. |
| **Full** (default) | `/caveman full` | Articles dropped, sentence fragments used. |
| Ultra | `/caveman ultra` | Abbreviates everything. One word enough. |

Plus a **Classical Chinese mode** for maximum compression.

## Companion tool — `caveman-compress`

Because CLAUDE.md loads every session, every token there costs for every session. `caveman-compress` rewrites it into a denser format.

**Reported savings: ~45% on CLAUDE.md compression alone.**

## Dunlop's adoption plan (from the article)

- **5 minutes:** install the plugin. One command, use it always.
- **15 minutes:** run `/caveman ultra` on your next session. Check your token count.
- **30 minutes:** run `caveman-compress` on your CLAUDE.md (~45% savings alone).

## Related Playbook pages

- [Cost & Observability]({{ site.baseurl }}/docs/cost-and-observability/) — full caveman setup + OpenTelemetry pairing
- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — CLAUDE.md authority-language upgrade
- [Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/) — xhigh default means caveman matters more than ever

## Useful verify path

Julius Brussee built the plugin. Article disclaims: *"I am not affiliated with Claude or the Caveman project. All thoughts are my own."* Dunlop repeatedly credits and links Brussee's GitHub.
