---
name: session-doubt
description: End-of-session doubt enumeration before claiming substantive work done. Surfaces (1) what the agent is least confident about — then root-causes each item — and (2) the biggest thing the user may not realize about the situation. A two-question reflective close-out, distinct from test-running verification. Triggers "/session-doubt", "doubt check", "what are you least confident about", "what am I missing", "close out the session", "least confident". Do NOT use for trivial edits, single-command tasks, lookups, or conversational turns — only substantive multi-step work where a missed assumption would be costly.
---

# session-doubt

Reflective close-out for substantive work. Two questions, asked in order. Source: end-of-session technique (Sam Altman's Q1 + a Claude-suggested Q2) — "1 in 4 times it surfaces a huge deal."

Run AFTER the work is otherwise complete (and ideally after `/done` / verification-before-completion has run). This is reflection, not test execution — the two are complementary, not substitutes.

## Q1 — Least confident

Ask yourself, honestly and without flattering the work:

> What am I least confident about right now? Enumerate everything.

- List **every** item, not a curated top-3. Aim for 5–8. Include things that feel minor.
- For each: one line stating the doubt + why.
- Then **root-cause the real ones**: pick the items where being wrong would actually matter and investigate each exhaustively (read the code, run the check, trace the path) until you understand the root cause — do not stop at restating the doubt.
- Be specific. "Error handling might be incomplete" is useless. "If the upload retries after a 413, we double-charge because the idempotency key is regenerated per-attempt — unverified" is useful.

## Q2 — Biggest blind spot

Then ask:

> What is the biggest thing the user does not realize about this situation right now?

- One thing. The single highest-leverage reframe, risk, or connection the user is most likely missing.
- It should change a decision, not just inform. Prefer the insight that contradicts or reframes something the user (or you) already assumed.

## Output

```
**Q1 — least confident (root-caused):**
1. <doubt> — <why> → <root-cause finding or "investigated: benign because …">
2. ...

**Q2 — biggest blind spot:**
<the one reframe, and what decision it changes>
```

Keep it tight. No reassurance padding. If genuinely nothing is uncertain, say so plainly — do not manufacture doubt to fill the list.
