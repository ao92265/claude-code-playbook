---
name: reap
description: Find and kill dead Claude sessions left running in detached tmux sessions after their terminal window was closed. Use when the session count in the status bar is higher than the number of windows on screen, or when the user says "/reap", "kill the dead sessions", "kill the dead ones", "clean up tmux", "close the idle sessions", "any zombie sessions", "why do I have 8 sessions", or asks to tidy up leftover sessions. Do NOT use to kill a session the user is actively looking at, to stop a background agent or launchd job, or to end the current session (that is /exit).
effort: low
---

# Reap dead tmux Claude sessions

Closing an iTerm window **detaches** a tmux session, it does not end it. Claude
keeps running with no window in front of it. That is how the session count drifts
above what is on screen.

This skill finds those, shows them, and kills them on the user's yes.

## What counts as dead

All five must hold. The script enforces every one, so do not hand-roll a
`tmux kill-session` loop instead of running it:

1. Not attached (no window in front of you)
2. Idle longer than the threshold, default 30 minutes, from tmux's own clock,
   and never less than 5 minutes however low `--minutes` is set
3. The pane is really running Claude, not a shell or a dev server
4. Nothing typed at the prompt, and no turn still running
5. Not the current session, and not on the protect list

## Procedure

1. **Scan.** Report only, never kills:

   ```
   ~/.claude/skills/reap/reap.sh
   ```

   Use `--minutes N` if the user wants a different idle threshold. The 30
   minute default hides a session orphaned minutes ago, so drop it when the
   user says the count is still wrong.

   It will not go below 5 minutes. tmux records no last-detached time, so a
   window closed a minute ago and a session abandoned overnight look the same,
   and a lower threshold reaps the window the user just walked away from. That
   is not theoretical: a `--minutes 1` run on 2026-09-09 killed a session that
   had been on screen moments earlier. Sessions held back by the floor say so
   in the SPARED list, so read it before assuming the flag was ignored.

2. **Show the user the DEAD list.** Name, idle time and the last line from each
   screen, so they can tell a finished job from an abandoned one. Also show the
   SPARED list: a session wrongly protected must be visible, not silent.

3. **Ask once.** Never kill without a yes in this turn. "Kill the dead ones" in
   the user's original message is a yes for that run.

4. **Kill.**

   ```
   ~/.claude/skills/reap/reap.sh --kill
   ```

   It rescans before killing, so a session that woke up in between is spared.

5. **Say what survived.** Report the killed names and the remaining count.

## Always tell them nothing is lost

`claude --resume` reopens any killed session's conversation. Say this whenever
a session with real work in it is on the kill list, so the decision is cheap.

## When the user wants a spared session killed anyway

`--ignore-typed` overrides the unsent-text rule only. Attached, protected,
current-session and still-working all still spare, so it cannot take out a
window the user is looking at or a bot.

Reach for it when the typed text is a question the user has already dealt with
elsewhere. Say what the text was before killing, so they can tell.

## The protect list

`~/.claude/skills/reap/protected.txt`, one tmux session name or glob per line.
Seeded with `cc-project-d` and `cc-event-b`: those bots run unattended, so
detached and idle is their normal healthy state, not a corpse.

Add a name here when the user says a session should never be reaped. Do not
solve it by raising the idle threshold.

## Not this skill's job

- Ending the session you are in: that is `/exit` or ctrl+d, which closes the
  tmux session with it.
- Plain terminal tabs that are not in tmux: those are visible to the user
  already, and killing them would close a window they are looking at.
- Background agents and launchd jobs: leave those to the referee and the
  graveyard sweep.

## It also runs on its own

A launchd job (`com.example.claude-reap`) runs `reap.sh --kill` every 30
minutes, same rules, never `--ignore-typed`. Log: `~/.claude/reap/launchd.log`.
Read that log before assuming a session was not reaped. Sessions with unsent
text still wait for a manual `/reap`.
