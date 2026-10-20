#!/usr/bin/env bash
# autoclear.sh on|off|status
#
# Global switch for auto clear: the run referee's rotate tier that types
# /reboot, /clear and a resume prompt into tmux sessions near the context or
# time wall. OFF by default. The flag file present means on. run-referee.py
# reads it every cycle, so a toggle needs no restart. /keep still pins single
# panes when it is on.
set -uo pipefail
F="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/rotate-enabled"
mkdir -p "$(dirname "$F")"

case "${1:-status}" in
  on)     date +%FT%T > "$F"
          echo "Auto clear ON. Sessions in tmux get rebooted, cleared and resumed near the wall. /autoclear off to stop." ;;
  off)    rm -f "$F"
          echo "Auto clear OFF. Nothing clears your sessions; past 4h they pause and you reboot by hand." ;;
  status) [ -f "$F" ] && echo "Auto clear ON since $(cat "$F")." || echo "Auto clear OFF." ;;
  *)      echo "usage: autoclear.sh on|off|status" >&2; exit 2 ;;
esac
