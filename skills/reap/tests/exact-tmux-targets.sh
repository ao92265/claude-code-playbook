#!/usr/bin/env bash
# tmux matches a -t target by prefix when no session has that exact name, so
# reaping "cc" after it exited could kill "cc-aoreilly-2" instead. Every target
# in reap.sh must use the "=" exact-match form. Part 2 checks those forms on a
# real tmux server, against private test sessions only.
set -uo pipefail
REAP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reap.sh"
FAILURES=0

loose=$(grep -nE 'tmux [a-z-]+ .*-t "\$' "$REAP" | grep -v -- '-t "=' || true)
if [ -n "$loose" ]; then
  echo "FAIL tmux targets without exact match:"; echo "$loose"; FAILURES=$((FAILURES+1))
else
  echo "ok   every tmux target in reap.sh is exact"
fi

if command -v tmux >/dev/null; then
  LONG="reapexact-$$-longer"
  SHORT="reapexact-$$"
  tmux new-session -d -s "$LONG" "sleep 60" || { echo "could not create fixture"; exit 2; }
  trap 'tmux kill-session -t "=$LONG" 2>/dev/null' EXIT
  if tmux list-panes -t "=$SHORT:" >/dev/null 2>&1; then
    echo "FAIL exact pane target matched a longer session"; FAILURES=$((FAILURES+1))
  else echo "ok   exact pane target ignores a longer session"; fi
  if tmux kill-session -t "=$SHORT" 2>/dev/null; then
    echo "FAIL exact kill target matched a longer session"; FAILURES=$((FAILURES+1))
  else echo "ok   exact kill target ignores a longer session"; fi
  tmux has-session -t "=$LONG" 2>/dev/null && echo "ok   longer session survived" \
    || { echo "FAIL longer session was killed"; FAILURES=$((FAILURES+1)); }
  tmux list-panes -t "=$LONG:" >/dev/null 2>&1 && echo "ok   exact pane target finds its own session" \
    || { echo "FAIL exact pane target missed its own session"; FAILURES=$((FAILURES+1)); }
else
  echo "skip: no tmux for part 2"
fi
[ "$FAILURES" -eq 0 ]
