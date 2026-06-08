#!/usr/bin/env bash
# research-only-guard.sh
#
# PreToolUse hook for Edit|Write|NotebookEdit. Blocks the call when the
# sentinel file `.claude/state/research-only.flag` is present in the working
# directory. The /research-only skill creates this flag on entry and removes
# it on clean exit, giving tool-level enforcement of research-only mode.
#
# When the flag is absent (the normal case), this hook is a no-op.
#
# Exit codes:
#   0 — flag absent, allow the tool call
#   2 — flag present, block the tool call (CC convention for hook denial)

set -euo pipefail

flag=".claude/state/research-only.flag"

if [ -f "$flag" ]; then
  cat >&2 <<'MSG'
[research-only-guard] BLOCKED — research-only mode is active.

Edit / Write / NotebookEdit are disabled while the sentinel file exists:
  .claude/state/research-only.flag

Deliver findings as markdown in the response instead. To exit research-only
mode and re-enable edits, remove the flag:
  rm .claude/state/research-only.flag
MSG
  exit 2
fi

exit 0
