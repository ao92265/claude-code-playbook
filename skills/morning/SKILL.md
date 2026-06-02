---
name: morning
description: >
  Cross-terminal morning briefing. Consolidates every parked Claude Code session
  into one report — branch, uncommitted state, recent asks, last action — so you
  resume 6-10 terminals without rereading each. Triggers: "morning", "morning
  briefing", "what were my terminals doing", "where did I leave off", "/morning".

  Do NOT use this skill for: a single-session recap (open that session's handoff
  directly), or planning new work.
metadata:
  user-invocable: true
  slash-command: /morning
  proactive: false
title: "Morning Briefing"
parent: Skills & Extensibility
---
# Morning Briefing

You run many Claude Code terminals at once and park them at end of day. This skill
reconstructs what each was doing from the central handoff store (written
automatically by the `stop-handoff.sh` Stop hook), so you can pick up cleanly.

## Steps

1. **Run the briefing script** (it does the scanning — don't hand-roll it):

   ```bash
   bash ~/.claude/scripts/morning.sh        # full detail for the 6 most-recent
   bash ~/.claude/scripts/morning.sh 12     # show more
   ```

   If the script is missing, fall back to listing the store directly:
   `ls -t ~/.claude/handoffs/*.md | grep -v compact` and `cat` the top few.

2. **Summarize for the user, don't dump.** Read the script output and present a
   tight digest:
   - One line per parked session: name, branch, uncommitted count, last ask.
   - Flag anything that looks mid-task or has a dirty tree that won't compile.
   - Surface open PRs that need attention.

3. **Recommend an order.** Suggest which terminal to resume first (e.g. the one
   with the most uncommitted work, or a blocked PR), and remind the user the model
   is **start a fresh session per worktree and let SessionStart inject the
   handoff** — not `claude --resume` on a bloated transcript.

## Notes

- The handoff files are machine-written and may be slightly stale — always verify
  `git status` / branch in the actual worktree before acting.
- For a curated, human-authored handoff of a single session, use `/handoff`
  (writes `SESSION_NOTES.md`); this skill is the cross-session roll-up.
- Pair with the **recon** TUI for live "which session needs input right now"
  status; `/morning` is the narrative catch-up, recon is the live overlay.
