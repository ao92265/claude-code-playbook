#!/usr/bin/env bash
# Drives the real reap.sh against a real detached tmux session.
#
# The bug this pins: on 2026-09-09 a "--minutes 1" run killed a session whose
# window had been closed about a minute earlier. To tmux, a window closed a
# minute ago and a session abandoned an hour ago look identical, so the
# threshold alone cannot tell them apart. reap now refuses to call anything
# idle under REAP_MIN_IDLE_SECONDS dead, whatever --minutes says.
#
# Second bug: reap read idle time from #{session_activity}, which tmux moves
# only on client key input. A detached session that is busy printing (an
# autonomous run, or session-rotate.sh typing via send-keys) looked idle for
# days and was called dead mid-work. The BUSY fixture stays quiet past the
# threshold, then prints: its session clock is old, its window clock is fresh.
set -uo pipefail

REAP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reap.sh"
FIX="$(mktemp -d)"
SESSION="reap-selftest-$$"
BUSY="reap-selftest-busy-$$"
FAILURES=0

# The fixture dir is a mktemp under the system temp dir and is left for the OS
# to clear: a scripted recursive delete is not worth the blast radius here.
cleanup() { tmux kill-session -t "$SESSION" 2>/dev/null; tmux kill-session -t "$BUSY" 2>/dev/null; }
trap cleanup EXIT

# A stand-in for the Claude CLI. reap identifies Claude by the pane process
# command, so the path has to end in /claude and the process has to stay up.
mkdir -p "$FIX/bin"
printf '%s\n' '#!/bin/sh' 'sleep 600' > "$FIX/bin/claude"
chmod +x "$FIX/bin/claude"

tmux new-session -d -s "$SESSION" -c "$FIX" "$FIX/bin/claude" || {
  echo "could not create the fixture session"; exit 2; }

# Same stand-in, but it prints output at 65s, after the 1 minute threshold.
mkdir -p "$FIX/busy/bin"
printf '%s\n' '#!/bin/sh' 'sleep 65' 'echo "working on it"' 'sleep 600' > "$FIX/busy/bin/claude"
chmod +x "$FIX/busy/bin/claude"
tmux new-session -d -s "$BUSY" -c "$FIX" "$FIX/busy/bin/claude" || {
  echo "could not create the busy fixture session"; exit 2; }

# Past the --minutes 1 threshold but under the floor. That gap is where the bug
# lived, so the wait is the test.
echo "waiting 75s for the fixture to cross the 1 minute threshold..."
sleep 75

check() {
  local label="$1" want="$2" runner="$3" sess="${4:-$SESSION}" out seen
  out="$("$runner" 2>&1)"
  if printf '%s\n' "$out" | awk '/^DEAD/{f=1} /^SPARED/{f=0} f' | grep -qE "$sess([[:space:]]|$)"; then
    seen=dead
  elif printf '%s\n' "$out" | awk '/^SPARED/{f=1} f' | grep -qE "$sess([[:space:]]|$)"; then
    seen=spared
  else
    seen=absent
  fi
  if [ "$seen" = "$want" ]; then
    echo "PASS  $label (saw: $seen)"
  else
    echo "FAIL  $label (wanted: $want, saw: $seen)"
    printf '%s\n' "$out" | sed 's/^/      /'
    FAILURES=$((FAILURES + 1))
  fi
}

# env -i: the C locale and bare environment the launchd job runs with.
run_default() { env -i HOME="$HOME" PATH="$PATH" "$REAP" --minutes 1; }
run_nofloor() { env -i HOME="$HOME" PATH="$PATH" REAP_MIN_IDLE_SECONDS=0 "$REAP" --minutes 1; }
export -f run_default run_nofloor 2>/dev/null

# 1. The regression: a session idle just over a minute survives --minutes 1.
check "freshly detached session is spared under the floor" spared run_default

# 2. The floor is what spares it, and the rest of the pipeline still works:
#    lift the floor and the same fixture is reaped.
check "same session is reaped once the floor is lifted" dead run_nofloor

# 3. Output in the pane counts as activity: the busy session is not idle.
check "session printing output is not idle" spared run_nofloor "$BUSY"

if [ "$FAILURES" -eq 0 ]; then echo "all checks passed"; else echo "$FAILURES check(s) failed"; fi
exit "$FAILURES"
