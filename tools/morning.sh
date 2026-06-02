#!/usr/bin/env bash
# Morning briefing — one consolidated view of every parked Claude Code session.
#
# Answers "what were all 8 of my terminals doing yesterday?" without opening each
# one. Read-only. Scans the central handoff store written by the Stop hook, plus
# your open PRs via gh. Pairs with the recon dashboard (live status) — this is the
# narrative; recon is the live overlay.
#
# Usage: morning.sh [N]   # show full detail for the N most-recent (default 6)
set -uo pipefail

HANDOFF_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/handoffs"
DETAIL_N="${1:-6}"

echo "# Morning briefing — $(date '+%Y-%m-%d %H:%M')"
echo

if [ ! -d "$HANDOFF_DIR" ] || [ -z "$(ls -A "$HANDOFF_DIR"/*.md 2>/dev/null || true)" ]; then
  echo "_No handoffs found in $HANDOFF_DIR — the handoff hooks may not be wired yet._"
  exit 0
fi

# Live handoffs only (exclude the .compact.md preservation files), newest first.
files=$(ls -t "$HANDOFF_DIR"/*.md 2>/dev/null | grep -v '\.compact\.md$' || true)

echo "## Parked sessions (newest first)"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  name=$(basename "$f" .md)
  when=$(date -r "$f" '+%m-%d %H:%M' 2>/dev/null || true)
  branch=$(grep -m1 '^- Branch:' "$f" 2>/dev/null | sed 's/^- Branch: //' || true)
  dirty=$(grep -m1 '^- Uncommitted:' "$f" 2>/dev/null | sed 's/^- Uncommitted: //' || true)
  echo "- **$name** — ${when:-?} — branch ${branch:-?} — ${dirty:-?} uncommitted"
done <<< "$files"

echo
echo "## Details (most recent $DETAIL_N)"
i=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  i=$((i+1)); [ "$i" -gt "$DETAIL_N" ] && break
  echo
  echo "----"
  cat "$f" 2>/dev/null || true
done <<< "$files"

if command -v gh >/dev/null 2>&1; then
  echo
  echo "## Your open PRs"
  gh search prs --author=@me --state=open --limit 20 2>/dev/null \
    || echo "_gh search unavailable (auth or network)_"
fi
