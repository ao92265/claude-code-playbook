#!/usr/bin/env bash
# SessionStart hook — surface daydreams generated while you were away.
#
# Companion to daydream.sh. If the detached daydream pass left a pending digest,
# print it once into the new session's context, then archive + clear it so it
# never repeats. Pure read + two file ops; always exits 0, never blocks.
#
# Kill switch:  OMC_SKIP_HOOKS=daydream   |   DISABLE_OMC
set -uo pipefail

cat >/dev/null 2>&1 || true   # drain SessionStart JSON (unused)

case ",${OMC_SKIP_HOOKS:-}," in *,daydream,*) exit 0 ;; esac
[ -n "${DISABLE_OMC:-}" ] && exit 0
# Never surface (and thus clear) the pending digest from inside the daydream
# child's own SessionStart — that would consume it before the user ever sees it.
[ -n "${DAYDREAM_CHILD:-}" ] && exit 0

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DD="$CFG/daydreams"
PEND="$DD/digest-pending.md"

[ -s "$PEND" ] || exit 0   # nothing pending

echo "=== 🌙 Daydreams while you were away (background musings — act only if useful) ==="
cat "$PEND"
echo "=== end daydreams ==="

# Surface once: archive then clear.
{ echo "--- surfaced $(date '+%Y-%m-%d %H:%M') ---"; cat "$PEND"; } >> "$DD/digest-archive.md" 2>/dev/null || true
: > "$PEND" 2>/dev/null || true

exit 0
