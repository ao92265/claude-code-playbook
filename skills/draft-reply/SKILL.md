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

## Drafting Rules

- Non-technical audience → no bullets unless explicitly requested. Conversational prose.
- Manager audience → lead with outcome/ask, technical detail only if requested.
- Engineer audience → bullets + code refs fine.
- Match the recipient's prior message style (formality, length) when reply thread exists.

## Output

Single draft. No "let me know if you want changes" coda — user will iterate naturally.

## Attribution

When naming people (PR authors, ticket owners) → verify via `gh` CLI / source-of-truth before draft. Don't guess from memory.
