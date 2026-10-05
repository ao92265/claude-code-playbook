---
name: coinrain
description: Manually trigger the coin-rain terminal animation and sound (the same effect that fires automatically on every Claude Code Stop event). Use when the user says "/coinrain", "test the coins", or wants to preview or debug Will's coin-rain hook without waiting for a real turn to end.
effort: low
---

Run the coin-rain script directly:

```bash
~/.claude/hooks/coin-rain.sh
```

This is the exact script wired into the `Stop` hook in `~/.claude/settings.json`. Use this skill only to preview/test it manually; it is not meant to be invoked as part of normal task completion.
