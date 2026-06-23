---
name: tldr
description: Restate my previous answer in plain English for a non-technical reader and end with the concrete next steps. Lead with a one-line TLDR, then a short plain-language explanation, then a Next steps list; define or avoid jargon, no new content. Triggers "/tldr", "tldr", "in plain english", "in english", "layman", "explain that simpler", "dumb it down", "eli5", "that was too technical". Do NOT use for drafting messages to other people (that's draft-reply), and not on code, commits, or technical reviews.
---

# tldr

Take my **last answer** and say it again in plain English, then tell the user what to do next. This is a re-express, not a new answer — no fresh content, no extra detail, no new questions.

## Output — three parts, in this order

1. `**TLDR:**` — one sentence. The bottom line, the thing they actually need to know.
2. **Plain explanation** — 2–5 short sentences in everyday words. An analogy only if it genuinely makes it clearer. No bullets unless the original was a list of separate things.
3. `**Next steps:**` — a short numbered list of the concrete actions to take now: what to do, where, and the exact command to type if there is one. **Mandatory — always present**, even if it's a single step.

## Rules

- **Next steps come from the original.** Pull them from the last answer — decisions to confirm, commands to run, things to check. Don't invent work. If the last answer genuinely needs no follow-up, write `**Next steps:** nothing to do — <one-line why>`.
- **Jargon:** swap technical terms for plain ones. If a term can't be avoided, define it inline in 4–6 words. No new acronyms.
- **Shorter than the original, always.** If the original was already plain, say so in one line — but still give the Next steps.
- **Caveman-lite compatible:** caveman cuts fluff, this cuts jargon. Output stays terse *and* plain. No conflict.

## Don't

- Don't restate code blocks line by line — summarize what the code does in one plain sentence.
- If the last turn was a draft meant for someone else (email/Slack/Teams), don't restate it here — point to the `draft-reply` skill instead.
