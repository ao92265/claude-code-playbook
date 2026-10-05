---
title: Session Lifecycle
nav_order: 11
parent: Advanced
---
# Session Lifecycle: handoff, reboot, rotation, referee

Long sessions get worse as they get longer. Context fills with tool output, early instructions
lose weight, and the model starts repeating itself. The fix is not a bigger window, it is making a
fresh start cost nothing.

## The loop

1. **Handoff on every turn.** `stop-handoff.sh` (Stop hook) writes a short handoff for the current
   repo and branch: the next intent, what was verified, uncommitted files, recent asks. It is
   overwritten every turn, so it is always current.
2. **`/reboot` then `/clear`.** `/reboot` writes a fuller handoff on demand. After `/clear`,
   `sessionstart-handoff.sh` loads it into the new session once. Two keystrokes, no copy and paste.
3. **Auto-rotation.** `scripts/claude-ops/session-rotate.sh` does step 2 for you. When a session
   passes a context threshold it sends `/reboot`, waits for the handoff, then `/clear`, through the
   session's tmux pane. The session comes back fresh and carries on. `/keep` pins a terminal so
   rotation never touches it.
4. **Continuation sessions state their own goal.** `leg-scope.sh` blocks the first edit of a
   resumed session until it says what would finish *this* leg (see [Guard Hooks](guard-hooks.md)).

Handoffs are keyed by repo plus branch, not by folder, so two sessions in the same directory on
different branches do not overwrite each other.

## The referee

`scripts/claude-ops/run-referee.py` runs every ten minutes from launchd. It reads live session
transcripts and applies mechanical rules (no model call):

| Verdict | When | Effect |
|---|---|---|
| PAUSE | Past four hours, or past the live-context ceiling | Guard hook blocks further tool calls until a human looks |
| KILL | Token budget blown, or an API-error loop | Blocks the session for good |
| none | Everything else | Nothing |

The policy is that a false kill costs more than a missed one, so it never kills on age alone.
Wrongly blocked: delete the sentinel file the guard names and the session continues.

## Housekeeping

| Tool | What it does |
|---|---|
| `session-load-guard.sh` | At session start, warns when more than three sessions are live or any is past four hours. Reports only |
| `/reap` | Kills Claude sessions left running in detached tmux sessions after their window was closed. Has a protect list |
| `checkpoint-sessions.sh` | Every 15 minutes, snapshots every live session's handoff so a machine reboot loses nothing |
| `/burn` | Projects the five-hour and weekly usage limits forward and names the session spending it |

## Rules that make this work

- One task per session. Switching task means `/clear` first.
- At about half context, write a handoff and clear. Do not wait for auto-compact.
- A handoff is a claim, not a fact. The next session re-checks branch and dirty state before acting.
