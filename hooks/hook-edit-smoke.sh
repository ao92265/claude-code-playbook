#!/usr/bin/env bash
# hook-edit-smoke.sh — PostToolUse(Edit|Write) hook.
# When a hook script under ~/.claude/hooks/ is edited, auto-run the hooks
# smoke test. On failure, emit the failing lines and exit 2 — PostToolUse
# exit 2 surfaces to the model without blocking the (already-landed) edit,
# so breakage gets fixed in the same turn. Operationalises the core-rules
# line "hooks-smoke-test.sh after editing any hook".
#
# Disable: CLAUDE_SKIP_HOOKS=hook-edit-smoke
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,hook-edit-smoke,*) exit 0 ;; esac

set -u

if ! command -v jq >/dev/null 2>&1; then exit 0; fi

INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  "$HOME/.claude/hooks/"*.sh) ;;
  *) exit 0 ;;
esac

SMOKE="$HOME/.claude/scripts/hooks-smoke-test.sh"
[ -f "$SMOKE" ] || exit 0

OUT=$(bash "$SMOKE" 2>&1)
if [ $? -ne 0 ]; then
  echo "hook-edit-smoke: hooks-smoke-test FAILED after edit of $FILE_PATH:" >&2
  printf '%s\n' "$OUT" | grep -E '^FAIL|^SLOW/BAD|FAILURES' >&2
  exit 2
fi
exit 0
