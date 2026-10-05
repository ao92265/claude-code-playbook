#!/usr/bin/env bash
# clean-transcript.sh — strip ANSI/control noise from a `script` typescript so a
# synthesizer can read the command sequence cleanly. Prints cleaned text to stdout.
# Usage: clean-transcript.sh <transcript.log>
set -euo pipefail
f="${1:?usage: clean-transcript.sh <transcript.log>}"
[ -f "$f" ] || { echo "not found: $f" >&2; exit 1; }

# Remove OSC sequences (ESC ] ... BEL), CSI sequences (ESC [ ... letter),
# other two-byte escapes, and carriage returns; drop the banner lines BSD
# `script` injects; collapse runs of blank lines.
# NB: backslash has no escape meaning inside a POSIX bracket expression, so
# `[^\x07]` would exclude the four literal characters \,x,0,7 rather than the
# BEL byte — that runs the OSC match past the terminator into whatever comes
# next. Build the BEL byte with $'\007' and splice it in so the bracket
# excludes the real control character.
BEL=$'\007'
LC_ALL=C sed -E \
  -e "s/\\x1b\\][0-9]*;?[^${BEL}]*${BEL}//g" \
  -e 's/\x1b\[[0-9;?]*[ -/]*[@-~]//g' \
  -e 's/\x1b[@-_]//g' \
  -e 's/\r//g' \
  "$f" \
| tr -d '\000-\010\013\014\016-\037' \
| grep -vE '^Script (started|done)' \
| cat -s
