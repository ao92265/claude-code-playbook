---
disable-model-invocation: true
name: afk
description: >
  Alias for `/auto away`. Unattended work that never waits on you: it decides the judgment
  calls itself, works the next-best-action ladder, and loops until the ladder is empty or a
  hard blocker lands. You come back to work done plus the calls it made, one line each.

  Triggers: "/afk", "afk", "afk mode", "I'm going out", "going afk", "work while I'm away",
  "don't wait for me", "keep going without me", "I'll be back in an hour".

  Do NOT use for: a task not yet started (state the task first), a run you intend to review
  step by step (that is `carryon`), or anything whose whole point is the decision itself.
metadata:
  user-invocable: true
  slash-command: /afk
  proactive: false
---

# afk

This is now `/auto away`. Read `~/.claude/skills/auto/SKILL.md` and follow it, starting at
section 3.

Flip the switch first:

```
python3 ~/.claude/hooks/auto-mode.py --on away
```

**What changed, August 2026.** afk used to write each judgment question into
`.omc/afk/decisions.md` along with the answer it would have chosen, and then deliberately
not act on it. That meant an unattended run came back as a to-do list rather than finished
work. `auto` decides instead. The hard stops are unchanged: irreversible, outward-facing,
protected paths, money, twice-failed, stuck, missing credential.

Flags carry over: `--dry` (name the picks, do nothing), `--no-push` (local and commit only),
`--until <condition>`.

Any older `.omc/afk/decisions.md` still on disk is a leftover from the banking era. Read it
if you want, but nothing writes to it now.
