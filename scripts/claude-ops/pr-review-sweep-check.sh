#!/bin/bash
# pr-review-sweep-check.sh — did this morning's PR review sweep actually work?
#
# The sweep posts unattended now (POST_SHARED_REPOS=1), so nobody reads an inbox
# any more and a silent failure would go unnoticed for days. This runs shortly
# after the sweep and notifies ONLY when something is wrong:
#
#   · no sweep log for today          → the launchd job did not fire
#   · the run reported failures       → reviews died mid-flight
#   · anything got parked             → a post was rejected and fell back to the
#                                       inbox, which is meant to stay empty
#
# A clean run says nothing at all. Exit 0 always — this is a reporter, not a gate.

set -uo pipefail

LOG_DIR="$HOME/logs"
TODAY=$(date '+%F')
LATEST=$(ls -t "$LOG_DIR"/pr-review-sweep-"$TODAY"-*.log 2>/dev/null | head -1)

notify() {
  /usr/bin/osascript -e "display notification \"$1\" with title \"PR review sweep\"" 2>/dev/null
  echo "$(date '+%F %T') $1" >> "$LOG_DIR/pr-review-sweep-check.log"
}

if [ -z "$LATEST" ]; then
  notify "No sweep ran today — check the launchd job."
  exit 0
fi

DONE_LINE=$(grep -- '=== done:' "$LATEST" | tail -1)

if [ -z "$DONE_LINE" ]; then
  notify "Sweep started but never finished. See ${LATEST##*/}"
  exit 0
fi

# "=== done: 3 reviewed · 3 posted · 0 parked · 8 skipped · 0 failed ==="
read -r PARKED FAILED <<<"$(printf '%s\n' "$DONE_LINE" \
  | sed -E 's/.* ([0-9]+) parked .* ([0-9]+) failed .*/\1 \2/')"

if [ "${FAILED:-0}" -gt 0 ] || [ "${PARKED:-0}" -gt 0 ]; then
  notify "${PARKED:-0} parked, ${FAILED:-0} failed. See ${LATEST##*/}"
fi

exit 0
