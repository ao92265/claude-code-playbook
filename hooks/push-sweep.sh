#!/usr/bin/env bash
# push-sweep.sh — Stop hook: surface unpushed commits before they strand.
# Born from myinsights scorecard 2026-07-02: push-through 54% (236 pushes / 437 commits)
# + the 874-commit project-a backlog. Warns once per repo+HEAD, never blocks.
set -euo pipefail

INPUT="$(cat 2>/dev/null || true)"
CWD="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("cwd",""))
except Exception: print("")' 2>/dev/null || true)"
[ -n "$CWD" ] && [ -d "$CWD" ] || exit 0
cd "$CWD" 2>/dev/null || exit 0

# not a git repo, or no remote to push to → nothing to sweep
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -n "$(git remote 2>/dev/null)" ] || exit 0

BRANCH="$(git branch --show-current 2>/dev/null || true)"
[ -n "$BRANCH" ] || exit 0   # detached HEAD → skip

# unpushed count: vs upstream if set, else anything not on any remote ref
if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  N="$(git rev-list '@{u}'..HEAD --count 2>/dev/null || echo 0)"
else
  N="$(git rev-list HEAD --not --remotes --count 2>/dev/null || echo 0)"
fi
[ "$N" -gt 0 ] 2>/dev/null || exit 0

# dedupe: warn once per repo+HEAD
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo x)"
STATE_DIR="$HOME/.claude/state/push-sweep"
mkdir -p "$STATE_DIR"
KEY="$STATE_DIR/$(printf '%s' "$CWD" | shasum | cut -c1-12)-$HEAD_SHA"
[ -f "$KEY" ] && exit 0
# keep state dir small: drop entries older than 7 days
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null || true
touch "$KEY"

REPO="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$CWD")")"
printf '{"systemMessage":"⬆ push-sweep: %s unpushed commit(s) on %s:%s — push or discard before parking the session (unpushed work is invisible + single-machine risk)."}\n' \
  "$N" "$REPO" "$BRANCH"
exit 0
