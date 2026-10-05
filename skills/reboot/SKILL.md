---
disable-model-invocation: true
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

Write the reprompt to a file. After `/clear`, the startup hook loads it back on its own — so there is usually nothing to paste.

1. **Pick the session name (slug) first.** If the session already has an explicit name AND that name describes the work this session actually did, REUSE it: the session keeps its identity across the clear. If the work drifted off the name (a pane named `innovation-team` that spent the day fixing Outlook), do NOT reuse it: invent a slug for the real work (`outlook-whatsapp-fix`). Stamping an errand with a project's name makes the next `/clear` load the errand as that project (2026-09-24). Read the current name with:

   ```bash
   . ~/.claude/hooks/lib/session-ident.sh && session_ident_name
   ```

   Empty output means the session is unnamed (auto-generated labels are filtered out): invent a short kebab-case slug of the task (e.g. `project-d-colleague-spec`, `planner-pill-qa`).

   The slug is **not** cosmetic: `sessionstart-handoff.sh` strips the `reboot-` prefix and the date off the filename and titles the cleared session with what is left, and it is the name the identity block stamps (step 3). Pick something that reads well in the prompt box and the `/resume` picker.

2. **Write the reprompt to a `.md` file.** Path: `~/.claude/reboots/reboot-<YYYY-MM-DD-HHMM>-<slug>.md` (create the dir if missing). The file body IS the reprompt, a direct instruction to a fresh Claude, fully self-contained (assume the reader saw none of this session; no "as discussed", no dangling pronouns).

   Writing the file also arms the same-terminal pickup: the `reboot-stamp.sh` PostToolUse hook drops a claim ticket keyed to this terminal's claude process, and `/clear` (which keeps that process) redeems it deterministically, no name matching involved. The identity block below is what covers every OTHER terminal.

3. **Stamp the identity block: do this every time, no exceptions.** Immediately after the H1 title, before any prose, insert the output of:

   ```bash
   ~/.claude/scripts/reboot-identity.sh "$PWD" <slug>
   ```

   Always pass the slug from step 1, inside a repo and out. It emits two or three lines, e.g.:

   ```
   - Path: `~/Repos/personal-os`
   - Branch: `main`
   - Session: personal-os-m4
   ```

   Safety net: the `reboot-stamp.sh` hook auto-inserts this block on any write to `~/.claude/reboots/` that lacks it (and adds a missing `- Session:` line to a half-stamped one), deriving the name from the filename slug. Still run the script yourself. The hook is the backstop, not the path.

   **Why it is mandatory:** outside this terminal, `sessionstart-handoff.sh` injects this file only when it can *prove* ownership from these lines. A file with no `- Session:` line is not even claimable by unnamed sessions any more (that ambiguity is how sibling sessions used to steal and burn reboots); it would only surface as a "may be yours" pointer. Run the script; do not hand-write the block, and never stamp a name you GUESSED from another session's files. The slug you chose deliberately is the right name.

4. **In chat, print three short lines:**
   - Line 1: why the session looks stale.
   - Line 2: `/clear`, nothing else.
   - Line 3: `/rename <slug>`, labelled as the fallback: "only if the name did not change".

   After `/clear` the new session loads this handoff and starts working on it without the user typing anything. It also renames itself from the slug, but that rename rides an undocumented field and has been seen not to land, so the `/rename` line is printed as a fallback rather than trusted silently. The cleared session prints the same line on screen, and only when the name actually failed to change, so in the good case there is nothing to do and the user simply ignores line 3.

   The one exception is a **different terminal**. A fresh launch is renamed and loaded but deliberately does *not* self-start — auto-start is limited to `/clear` so that scripted and scheduled runs can never be diverted into executing a leftover reboot. So give a paste line only in that case:

   ```
   claude -n project-d-colleague-spec
   Read ~/.claude/reboots/reboot-2026-06-29-1542-project-d-colleague-spec.md and continue from it.
   ```

The handoff loads **once**. A second `/clear` will not replay it — that is deliberate, so one reboot does not follow the user around for a week. Re-run `/reboot` if a fresh one is needed.

If a reboot records **finished** work, say so plainly in the file. The auto-start message tells the resumed session to stop rather than invent follow-up work, but only the handoff itself can say which case it is.

## Honesty

Don't invent state. If branch, dirty files, or anything else is uncertain, write "verify before acting" instead of asserting it — same disclaimer the handoff itself uses. A wrong "current state" is worse than an admitted gap.
