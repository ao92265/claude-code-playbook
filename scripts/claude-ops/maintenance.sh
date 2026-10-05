#!/usr/bin/env bash
# ~/.claude maintenance — prune stale state, report sizes.
# Run weekly: bash ~/.claude/scripts/maintenance.sh
# Cron: 0 9 * * 1 bash ~/.claude/scripts/maintenance.sh >> ~/.claude/scripts/maintenance.log 2>&1

set -u
cd "$HOME/.claude" || exit 1

echo "=== maintenance $(date) ==="
BEFORE=$(du -sh . 2>/dev/null | awk '{print $1}')

# Session JSONLs older than 60d
find projects -type f -name "*.jsonl" -mtime +60 -delete 2>/dev/null
find projects -type d -empty -delete 2>/dev/null

# File history older than 14d
find file-history -type f -mtime +14 -delete 2>/dev/null

# Caches older than 7d
find paste-cache -type f -mtime +7 -delete 2>/dev/null
find read-once -type f -mtime +7 -delete 2>/dev/null
find shell-snapshots -type f -mtime +7 -delete 2>/dev/null

# Todos older than 14d
find todos -type f -mtime +14 -delete 2>/dev/null

# Telemetry failed events (always safe)
find telemetry -name "1p_failed_events.*" -delete 2>/dev/null

# Stale .claude.json backups (>30d)
find backups -name ".claude.json.backup.*" -mtime +30 -delete 2>/dev/null

# Stale CLAUDE.md backups (>30d)
find . -maxdepth 1 -name "CLAUDE.md.backup.*" -mtime +30 -delete 2>/dev/null
find . -maxdepth 1 -name "CLAUDE.md.bak.*" -mtime +30 -delete 2>/dev/null

# Stale config-file backup sprawl (>30d): settings.json.bak*, hooks/*.bak, plugins/*.json.bak
find . -maxdepth 1 -name "settings.json.bak*" -mtime +30 -delete 2>/dev/null
find hooks -name "*.bak*" -mtime +30 -delete 2>/dev/null
find plugins -maxdepth 1 -name "*.json.bak*" -mtime +30 -delete 2>/dev/null

# THE BIG RECLAIM: stale per-task agent worktree session dirs under projects/ (>14d).
# These accumulate ~3000 dirs and dominate ~/.claude size; the 60d *.jsonl rule above
# reclaims almost nothing because the dirs (not just loose jsonl) are the bulk.
find projects -maxdepth 1 -type d -name "*agent-worktrees*TASK-*" -mtime +14 -exec rm -rf {} + 2>/dev/null

# Handoff snapshots older than 30d (live handoffs are path-keyed + self-overwriting,
# so only genuinely stale per-session files age out here).
find handoffs -name "*.md" -mtime +30 -delete 2>/dev/null

# Prune stale git worktree admin entries across all repos.
# Safe: `worktree prune` only drops entries whose working dir is already gone —
# it never removes a live worktree or deletes a branch.
for repo in "$HOME"/Repos/*/; do
  [ -d "${repo}.git" ] || continue
  git -C "$repo" worktree prune 2>/dev/null || true
done

# Is the learn-from-me loop actually closing? Reports approval rate, whether
# corrections arrive via auto-detection or manual marker, and (the one that
# matters) whether logged corrections became feedback memories or evaporated.
[ -x "$HOME/.claude/scripts/feedback-stats.sh" ] && \
  bash "$HOME/.claude/scripts/feedback-stats.sh" 7 2>/dev/null

# User-owned rule-line cap (<150 across all layers; core-rules.md "Maintenance & Meta").
# CLAUDE.md is OMC-managed except the user's @-import lines, so only those count.
RULE_LINES=$(cat core-rules.md RTK.md factual-guardrails.md workflow-rules.md design-rules.md 2>/dev/null | wc -l | awk '{print $1}')
CLAUDE_OWNED=$(grep -c '^@' CLAUDE.md 2>/dev/null) || CLAUDE_OWNED=0
RULE_TOTAL=$((RULE_LINES + CLAUDE_OWNED))
echo "rule lines: $RULE_TOTAL/150 (rule files $RULE_LINES + CLAUDE.md @-imports $CLAUDE_OWNED)"
if [ "$RULE_TOTAL" -ge 150 ]; then
  echo "WARN: user-owned rule lines $RULE_TOTAL >= 150 cap — prune (core-rules.md Maintenance & Meta)"
fi

# Codex stop-gate patch (cheap model + skip no-op turns). The plugin lives in a
# version-pinned cache dir, so a plugin update silently reverts it and reviews
# go back to the expensive model. Idempotent — re-applies only when needed.
[ -x "$HOME/.claude/scripts/codex-gate-patch.sh" ] && \
  bash "$HOME/.claude/scripts/codex-gate-patch.sh" 2>&1 | tail -1

# Prove the patched gate still behaves: fails open when Codex gives no verdict,
# still blocks on a real BLOCK. A plugin update can move the anchors silently.
[ -x "$HOME/.claude/scripts/codex-gate-hook-test.sh" ] && \
  bash "$HOME/.claude/scripts/codex-gate-hook-test.sh" 2>/dev/null | tail -1

AFTER=$(du -sh . 2>/dev/null | awk '{print $1}')
echo "size: $BEFORE -> $AFTER"
echo "biggest dirs:"
du -sh */ 2>/dev/null | sort -rh | head -5
echo "=== done ==="
