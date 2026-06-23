---
name: reboot
description: Distill the current task and state into a clean, self-contained reprompt to paste into a fresh session, so a stale or bloated context can be cleared without losing the thread. Triggers "/reboot", "reboot this session", "this session is stale", "stale session", "clear and reprompt", "reprompt me", "fresh start", "this session's getting old". Do NOT use for a cross-terminal morning digest (that's morning) or to actually run /clear (it can't — it emits the reprompt, you clear).
---

# reboot

The session is old or bloated and should be cleared. Your job: hand the user a clean, self-contained prompt they can paste into a **fresh** session and keep going — no thread lost.

You can't run `/clear` yourself. You produce the reprompt; the user clears and pastes.

## Sources

- **Primary: the current conversation** you already hold. That's the real source of the goal and state.
- **Cross-check / fill gaps:** the freshest handoff in `~/.claude/handoffs/` — pick the one matching the current working directory, else the most recently modified — and its `.compact.md` sibling if present. These are the same sources `sessionstart-handoff.sh` re-injects into a new session.

## Distill into the reprompt

Capture only what a fresh Claude needs:

- **Goal** — what "done" looks like, in one or two lines.
- **State** — what's already done / decided.
- **Next step** — the immediate thing to do.
- **Constraints** — hard rules or decisions already locked in.
- **Key paths** — files/dirs in play.

Drop dead-ends, resolved tangents, and tool noise.

## Output

Two short lines first: why the session looks stale, and what to do — `/clear` (or open a new terminal), then paste the block below.

Then **one fenced code block** = the paste-ready reprompt. Write it as a direct instruction to a fresh Claude. It must be fully self-contained — assume the reader saw none of this session. No "as discussed", no dangling pronouns.

## Honesty

Don't invent state. If branch, dirty files, or anything else is uncertain, write "verify before acting" instead of asserting it — same disclaimer the handoff itself uses. A wrong "current state" is worse than an admitted gap.
