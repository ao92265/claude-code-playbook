#!/usr/bin/env bash
# SessionStart hook — surface daydreams generated while you were away.
#
# Companion to daydream.sh. If the detached daydream pass left a pending digest,
# print it once into the new session's context, then archive + clear it so it
# never repeats. Pure read + two file ops; always exits 0, never blocks.
#
# Kill switch:  CLAUDE_SKIP_HOOKS=daydream   |   CLAUDE_DISABLE_HOOKS
set -uo pipefail

cat >/dev/null 2>&1 || true   # drain SessionStart JSON (unused)

SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,daydream,*) exit 0 ;; esac
[ -n "${CLAUDE_DISABLE_HOOKS:-}${DISABLE_OMC:-}" ] && exit 0
# Never surface (and thus clear) the pending digest from inside the daydream
# child's own SessionStart — that would consume it before the user ever sees it.
[ -n "${DAYDREAM_CHILD:-}" ] && exit 0

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DD="$CFG/daydreams"
# Daily lane and weekly big-bets lane each leave their own pending digest.
for PEND in "$DD/digest-pending.md" "$DD/digest-pending-bets.md"; do
  [ -s "$PEND" ] || continue   # nothing pending in this lane

  echo "=== 🌙 Daydreams while you were away (background musings — act only if useful) ==="
  # Filtered read, not a bare cat: the digest is model-written, so an ANSI or OSC 52
  # sequence planted upstream would otherwise reach the terminal verbatim. Tab and
  # newline survive (this is multi-line markdown), ESC/BEL/CR/NUL/DEL do not.
  tr -d '\000-\010\013-\037\177' < "$PEND" 2>/dev/null || cat "$PEND"
  echo "=== end daydreams ==="

  # Surface once: archive then clear.
  { echo "--- surfaced $(date '+%Y-%m-%d %H:%M') ---"; cat "$PEND"; } >> "$DD/digest-archive.md" 2>/dev/null || true
  : > "$PEND" 2>/dev/null || true
done

exit 0
