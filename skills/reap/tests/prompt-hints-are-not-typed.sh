#!/usr/bin/env bash
# Drives the real reap.sh against real detached tmux sessions, one per pane
# picture, each running a fake claude that prints the picture and then waits.
#
# The bug this pins: on 2026-09-27 reap spared four dead sessions as having
# "unsent text at the prompt". None of them had anything a person typed:
#   - Claude's grey placeholder hint, ❯ Try "fix typecheck errors"
#   - the rotation script's resume line, typed in but never sent with Enter
#   - a numbered permission menu, whose ❯ row reads like typed text
# The first two are dead. The menu is live state, so it is spared, but as a
# dialog, not as typed text. Real half-written text must still be spared.
#
# Second bug, same day: the fixtures used to print an ASCII space after ❯, but
# Claude draws a no-break space (bytes c2 a0) there. The launchd job runs in the
# C locale, where [:space:] does not match it, so every prompt, even an empty
# one, read as typed text and the scheduled reaper spared everything. So the
# fixtures now draw the real bytes, the placeholder is dim like the real one,
# and reap runs under env -i, the way launchd runs it.
set -uo pipefail

REAP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reap.sh"
FIX="$(mktemp -d)"
PREFIX="reap-hinttest-$$"
FAILURES=0
SESSIONS=()

# The fixture dir is a mktemp under the system temp dir and is left for the OS
# to clear: a scripted recursive delete is not worth the blast radius here.
cleanup() { for s in "${SESSIONS[@]}"; do tmux kill-session -t "$s" 2>/dev/null; done; }
trap cleanup EXIT

RULE='────────────────────────────────────────'
STATUS='  20:42  Opus5.5 1M  thinking  ctx:0%'

# One fixture: $1 is the case name, the rest are the pane lines. reap spots
# Claude by the process command, so the script has to live at .../claude.
make_case() {
  local name="$1"; shift
  local dir="$FIX/$name/bin"
  mkdir -p "$dir"
  # The picture goes in a data file and is cat'ed, so escape codes and the
  # no-break space reach the pane byte for byte, with no shell quoting between.
  printf '%s\n' "$@" > "$FIX/$name/screen"
  printf '%s\n' '#!/bin/sh' "cat '$FIX/$name/screen'" 'sleep 600' > "$dir/claude"
  chmod +x "$dir/claude"
  tmux new-session -d -x 80 -y 24 -s "$PREFIX-$name" -c "$FIX" "$dir/claude" || {
    echo "could not create fixture $name"; exit 2; }
  SESSIONS+=("$PREFIX-$name")
}

# What Claude really draws: ❯, then a no-break space, not an ASCII one.
P="❯$(printf '\302\240')"
DIM="$(printf '\033[2m')"; OFF="$(printf '\033[0m')"

make_case placeholder "$RULE" "${P}${DIM}Try \"fix typecheck errors\"${OFF}" "$RULE" "$STATUS"
# Any other dim suggestion Claude puts in the box is not typed either.
make_case dimother "$RULE" "${P}${DIM}ask about the diff above${OFF}" "$RULE" "$STATUS"
make_case empty "$RULE" "$P" "$RULE" "$STATUS"
make_case resume "$RULE" "${P}Continue from the reboot handoff above. If" \
  '  it reports the work already finished, say so' \
  '  and stop, do not invent follow-up work.' "$RULE" "$STATUS"
# A narrow pane wraps the resume line early, so only a stub sits on the ❯ row.
make_case resumenarrow "$RULE" "${P}Continue from the reboot" \
  '  handoff above. If it reports the work' "$RULE" "$STATUS"
make_case menu "$RULE" '   Claude has written up a plan and' \
  '   is ready to execute. Would you' '   like to proceed?' \
  "   ${P}1. Yes, and switch to BYPASS" '        PERMISSIONS (no further' \
  '     2. Yes, manually approve edits' '     3. Tell Claude what to change'
make_case typed "$RULE" "${P}half written message" "$RULE" "$STATUS"
# Typed by a person, shaped exactly like the placeholder, but not dim.
make_case typedtry "$RULE" "${P}Try \"pnpm build\"" "$RULE" "$STATUS"

# Let the fake claudes paint before reap reads the panes.
sleep 2

# Floor lifted and --minutes 0, so idle time never decides: the pane does.
# env -i: the C locale and bare environment the launchd job runs with.
OUT="$(env -i HOME="$HOME" PATH="$PATH" REAP_MIN_IDLE_SECONDS=0 "$REAP" --minutes 0 2>&1)"

check() {
  local label="$1" name="$2" want="$3" why="${4:-}" seen row
  row="$(printf '%s\n' "$OUT" | grep -E "^[[:space:]]+$PREFIX-$name([[:space:]]|$)")"
  if printf '%s\n' "$OUT" | awk '/^DEAD/{f=1} /^SPARED/{f=0} f' | grep -qE "$PREFIX-$name([[:space:]]|$)"; then
    seen=dead
  elif printf '%s\n' "$OUT" | awk '/^SPARED/{f=1} f' | grep -qE "$PREFIX-$name([[:space:]]|$)"; then
    seen=spared
  else
    seen=absent
  fi
  if [ "$seen" = "$want" ] && { [ -z "$why" ] || printf '%s' "$row" | grep -q "$why"; }; then
    echo "PASS  $label (saw: $seen)"
  else
    echo "FAIL  $label (wanted: $want${why:+, $why}, saw: $seen)"
    echo "      row: $row"
    FAILURES=$((FAILURES + 1))
  fi
}

check "dim placeholder hint is not typed text" placeholder dead
check "other dim suggestion is not typed text" dimother dead
check "empty prompt (no-break space) is not typed text" empty dead
check "unsent resume line is not typed text" resume dead
check "resume line wrapped early is not typed text" resumenarrow dead
check "numbered menu is a dialog" menu spared "waiting on a dialog"
check "real half-written text is still spared" typed spared "unsent text at the prompt"
check "typed text shaped like the placeholder is spared" typedtry spared "unsent text at the prompt"

if [ "$FAILURES" -eq 0 ]; then echo "all checks passed"; else echo "$FAILURES check(s) failed"; fi
exit "$FAILURES"
