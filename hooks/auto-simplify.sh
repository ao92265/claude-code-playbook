#!/usr/bin/env bash
case ",${OMC_SKIP_HOOKS:-}," in *,auto-simplify,*) exit 0 ;; esac
# Auto-simplify hook — runs on Bash tool calls matching "git commit"
# Uses codex (gpt-5 xhigh) review of staged diff. Blocks on [P1] findings.

INPUT=$(cat 2>/dev/null || true)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

set -euo pipefail

# Extract target dir if "cd /path && git commit"
GIT_DIR=""
if echo "$COMMAND" | grep -qE '^cd ([^ ]+)'; then
  GIT_DIR=$(echo "$COMMAND" | sed -E 's/^cd ([^ &]+).*/\1/')
fi
[ -n "$GIT_DIR" ] && cd "$GIT_DIR" 2>/dev/null || true

if ! git rev-parse --is-inside-work-tree &>/dev/null; then exit 0; fi

# Skip tiny diffs
LINES_ADDED=$(git diff --cached --numstat 2>/dev/null | awk '{s+=$1} END{print s+0}')
[ "${LINES_ADDED:-0}" -lt 50 ] && exit 0

if ! command -v codex &>/dev/null; then exit 0; fi

# Run codex review with portable 150s timeout (no GNU coreutils dependency)
RAW_OUT=$(mktemp -t codex-simplify.XXXXXX)
codex exec review --uncommitted --json --skip-git-repo-check > "$RAW_OUT" 2>/dev/null &
PID=$!
( sleep 150; kill -9 $PID 2>/dev/null ) &
WD=$!
wait $PID 2>/dev/null
CODE=$?
kill -9 $WD 2>/dev/null || true

if [ "$CODE" -ne 0 ] || [ ! -s "$RAW_OUT" ]; then
  rm -f "$RAW_OUT"
  exit 0
fi

REVIEW=$(jq -r 'select(.type=="item.completed" and .item.type=="agent_message") | .item.text' "$RAW_OUT" 2>/dev/null | tail -200)
rm -f "$RAW_OUT"

if [ -z "$REVIEW" ]; then exit 0; fi

# Print review for visibility
echo "" >&2
echo "═══ Codex Pre-Commit Review (gpt-5) ═══" >&2
echo "$REVIEW" >&2
echo "════════════════════════════════════════" >&2

# Block only on P1 findings; P2/P3 advisory
if echo "$REVIEW" | grep -qE '\[P1\]'; then
  echo "" >&2
  echo "Commit blocked — fix [P1] issues above and retry." >&2
  exit 2
fi

exit 0
