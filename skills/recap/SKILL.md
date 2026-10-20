---
name: recap
description: Say where this session is - its big goal, any side-track in progress, and the next step - in three plain lines. Use when the user says "/recap", "where are we", "what were we doing", "remind me", "what's the plan", "I've lost track". Do NOT use for a cross-session status board or a handoff file (that is /reboot).
---

1. Run `python3 ~/.claude/hooks/goal-pin.py --show "$CLAUDE_CODE_SESSION_ID"`.
2. Reply with three plain lines: the goal, the side-track (or "none"), and the next step on the goal. Use the conversation to fill the next step.
3. If the stored goal is wrong or missing, ask the user for it in one line, then record it with `echo "goal: <one line>"`.
