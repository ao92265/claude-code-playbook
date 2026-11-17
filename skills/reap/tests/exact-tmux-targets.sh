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

# Window and pane commands need the trailing colon: "=name" alone is read as a
# pane when the name holds a dot (v1.2-fix), and the command fails.
nocolon=$(grep -nE 'tmux (list-windows|list-panes|capture-pane) .*-t "=\$[A-Za-z_]+"' "$REAP" || true)
if [ -n "$nocolon" ]; then
  echo "FAIL window or pane targets without the trailing colon:"; echo "$nocolon"; FAILURES=$((FAILURES+1))
else
  echo "ok   window and pane targets end in a colon"
fi

if command -v tmux >/dev/null; then
  LONG="reapexact-$$-longer"
  SHORT="reapexact-$$"
  DOT="reapdot-$$.v2"
  tmux new-session -d -s "$LONG" "sleep 60" || { echo "could not create fixture"; exit 2; }
  tmux new-session -d -s "$DOT" "sleep 60" || { echo "could not create dotted fixture"; exit 2; }
  trap 'tmux kill-session -t "=$LONG" 2>/dev/null; tmux kill-session -t "=$DOT" 2>/dev/null' EXIT
  tmux list-windows -t "=$DOT:" >/dev/null 2>&1 && echo "ok   window target works for a dotted session name" \
    || { echo "FAIL window target failed for a dotted session name"; FAILURES=$((FAILURES+1)); }
  tmux list-panes -t "=$DOT:" >/dev/null 2>&1 && echo "ok   pane target works for a dotted session name" \
    || { echo "FAIL pane target failed for a dotted session name"; FAILURES=$((FAILURES+1)); }
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
