#!/usr/bin/env bash
case ",${OMC_SKIP_HOOKS:-}," in *,codex-prepush-review,*) exit 0 ;; esac
# Codex pre-push review — fires on Bash tool calls matching "git push"
# Uses codex (gpt-5 xhigh) review of HEAD vs main/master. Blocks on [P1] findings.

INPUT=$(cat 2>/dev/null || true)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

case "$COMMAND" in
  *"git push"*) ;;
  *) exit 0 ;;
esac

set -euo pipefail

if ! git rev-parse --is-inside-work-tree &>/dev/null; then exit 0; fi

# Pick base branch
BASE="main"
if ! git rev-parse --verify "$BASE" &>/dev/null; then
  BASE="master"
  if ! git rev-parse --verify "$BASE" &>/dev/null; then
    exit 0
  fi
fi

# Skip if no diff vs base
if [ -z "$(git diff "$BASE"...HEAD 2>/dev/null)" ]; then
  exit 0
fi

if ! command -v codex &>/dev/null; then exit 0; fi

RAW_OUT=$(mktemp -t codex-prepush.XXXXXX)
codex exec review --base "$BASE" --json --skip-git-repo-check > "$RAW_OUT" 2>/dev/null &
PID=$!
( sleep 180; kill -9 $PID 2>/dev/null ) &
WD=$!
wait $PID 2>/dev/null
CODE=$?
kill -9 $WD 2>/dev/null || true

if [ "$CODE" -ne 0 ] || [ ! -s "$RAW_OUT" ]; then
  echo "Codex pre-push review failed/timed out — allowing push." >&2
  rm -f "$RAW_OUT"
  exit 0
fi

REVIEW=$(jq -r 'select(.type=="item.completed" and .item.type=="agent_message") | .item.text' "$RAW_OUT" 2>/dev/null | tail -200)
rm -f "$RAW_OUT"

if [ -z "$REVIEW" ]; then exit 0; fi

echo "" >&2
echo "═══ Codex Pre-Push Review (gpt-5, vs $BASE) ═══" >&2
echo "$REVIEW" >&2
echo "═══════════════════════════════════════════════" >&2

if echo "$REVIEW" | grep -qE '\[P1\]'; then
  echo "" >&2
  echo "Push blocked — fix [P1] blockers and retry." >&2
  exit 2
fi

exit 0
