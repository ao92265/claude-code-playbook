---
description: Show, clear, or manually pin the session's open question
argument-hint: "[nothing = show | done = clear | <text> = pin manually]"
allowed-tools: Bash
---

Manage the pinned open question for this session. `$ARGUMENTS` decides the mode:

- **empty** — run `python3 ~/.claude/hooks/open-question.py --show` and report what
  it prints. If a question is open, answer it now, then clear it.
- **`done`, `clear`, `resolve`, `answered`, `ok`** — run
  `python3 ~/.claude/hooks/open-question.py --resolve` and confirm in one line.
- **anything else** — treat it as a question to pin:
  `python3 ~/.claude/hooks/open-question.py --pin "$ARGUMENTS"`, then answer it.

Keep the reply to one or two lines. The pinned question also shows at the bottom of
the screen under the status line, and is re-injected every turn until cleared.
