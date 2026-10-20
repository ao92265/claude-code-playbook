---
name: autoclear
description: Turn auto clear (the automatic reboot, clear and resume of tmux sessions near the context or time wall) on or off for every session, or show whether it is on. Off by default. Use when the user says "/autoclear", "/autoclear on", "/autoclear off", "turn auto clear on/off", "stop auto clearing", "turn off auto reboot", "is auto clear on". Do NOT use to pin just one terminal (that is keep) or to kill sessions (that is reap).
effort: low
---

# /autoclear

Run exactly one command, then reply with its output line and nothing else.

- `/autoclear on`: `~/.claude/scripts/autoclear.sh on`
- `/autoclear off`: `~/.claude/scripts/autoclear.sh off`
- `/autoclear` or `/autoclear status`: `~/.claude/scripts/autoclear.sh status`

The switch covers every session at once and takes effect on the referee's next
10-minute cycle. When it is off, a session past 4h or 400k context gets the old
pause and notification instead.
