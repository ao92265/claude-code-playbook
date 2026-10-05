---
name: keep
description: Pin this terminal so the automatic reboot, clear and resume never touches it, or unpin it again. Use when the user says "/keep", "keep this terminal", "don't clear this one", "pin this session", "leave this open", or "/keep off" to undo, "/keep status" to check. Do NOT use to stop a session, kill tmux sessions (that is reap) or turn rotation off everywhere.
effort: low
---

# /keep

Run exactly one command, then reply with its output line and nothing else.

- `/keep` or `/keep on`: `~/.claude/scripts/keep.sh on`
- `/keep off`: `~/.claude/scripts/keep.sh off`
- `/keep status`: `~/.claude/scripts/keep.sh status`

A pinned terminal still gets the old pause and notification past 4h or 400k
context. It just never has its screen cleared. The pin lasts until `/keep off`
or until the tmux pane closes.
