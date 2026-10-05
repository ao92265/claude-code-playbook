---
name: draft-reply
description: Audience-first drafting for replies/emails/Slack/Teams. Forces recipient + tone framing before writing. Triggers "/draft-reply", "draft a reply", "write a slack message", "draft an email".
---

# Draft Reply

Prevents the recurring "first draft too technical, needs tone rework" friction.

## Pre-Write Checklist (ASK IF UNSPECIFIED)

Before writing a single word, confirm:

1. **Recipient:** name + role
2. **Technical level:** engineer / manager / non-technical
3. **Tone:** formal / conversational / terse / warm
4. **Desired action:** what should the reader do after reading?
5. **Format:** Slack thread / email / Teams / inline comment
6. **Length cap:** sentence / paragraph / multi-paragraph

If ANY are unspecified and not obvious from context → ASK before drafting. Single batched question.

7. **Persona check:** recipient is a named person? Check the mindmirror persona bank first (`/persona` skill → `ask "<person>" "<their message>"`). If a card exists, use its read + response guidance to shape tone and framing. No card / CLI missing → proceed without it, don't block.

## Drafting Rules

- Non-technical audience → no bullets unless explicitly requested. Conversational prose.
- Manager audience → lead with outcome/ask, technical detail only if requested.
- Engineer audience → bullets + code refs fine.
- Match the recipient's prior message style (formality, length) when reply thread exists.

## Output

Single draft. No "let me know if you want changes" coda — user will iterate naturally.

**MANDATORY final pass:** before presenting any publishable draft, run it through the `anti-ai-prose` skill to strip AI tells (standing rule — do not ask first). Prose only; never on code, commits, or technical reviews. If `anti-ai-prose` is unavailable, de-slop manually (cut hedging, em-dash pile-ups, "it's worth noting", rule-of-three padding).

## Attribution

When naming people (PR authors, ticket owners) → verify via `gh` CLI / source-of-truth before draft. Don't guess from memory.
