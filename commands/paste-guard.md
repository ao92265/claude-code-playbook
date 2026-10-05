---
description: Turn the paste DLP guard off or back on, or report which layers are live
argument-hint: "[off | on | status (default)]"
allowed-tools: Bash
---

Switch the paste guard. It covers both layers at once (the Claude prompt hook and the
Hammerspoon clipboard sanitizer), because both read the same state file.
`$ARGUMENTS` decides the mode:

- **`off`, `disable`, `stop`**: run
  `mkdir -p ~/.claude/state/paste-guard && touch ~/.claude/state/paste-guard/off`
  then confirm in one line: guard off until turned back on, both layers, survives restarts.
- **`on`, `enable`, `start`**: run
  `rm -f ~/.claude/state/paste-guard/off`
  then confirm in one line.
- **empty, `status`, anything else**: run
  `test -f ~/.claude/state/paste-guard/off && echo OFF || echo ON`
  and report it plainly. If it is ON, also mention the two per-message escapes:
  start the message with `!!raw`, or `/paste-guard off`.

Keep the reply to one line. Do not read or print the guard's log.

Note for anyone editing this: an `export PASTE_GUARD_DISABLED=1` typed inside a session
cannot work. Hooks inherit the environment `claude` was launched with, so the export dies
with its subshell. That is why the switch is a file.
