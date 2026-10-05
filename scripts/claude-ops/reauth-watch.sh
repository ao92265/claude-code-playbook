#!/usr/bin/env bash
# reauth-watch.sh — reconcile a stale daemon-auth-status.json and alert on a
# genuine re-auth need. Run by launchd every 60s (com.example.claude-reauth-watch).
#
# Background: daemon-auth-status.json can get stuck at {"status":"auth_required"}
# even after the daemon recovers the token via keychain — the recovery path never
# rewrites the file (observed stuck since 2026-05-22). This reconciles the false
# positive and only notifies when re-auth is actually needed.
set -uo pipefail

CLAUDE_DIR="$HOME/.claude"
STATUS_FILE="$CLAUDE_DIR/daemon-auth-status.json"
LOG="$CLAUDE_DIR/daemon.log"

[ -f "$STATUS_FILE" ] || exit 0
status=$(jq -r '.status // empty' "$STATUS_FILE" 2>/dev/null || true)
[ "$status" = "auth_required" ] || exit 0

# Most recent auth-relevant daemon.log line decides recovered-vs-needed.
recent=""
[ -f "$LOG" ] && recent=$(grep -E 'token found|token still valid|re-auth required|no token found|proactive refresh failed' "$LOG" 2>/dev/null | tail -1)

# Only reconcile if the recovery line is NEWER than the flag's own 'since' timestamp —
# otherwise a successful refresh that PRECEDED a later auth_required would wrongly clear it.
since_ms=$(jq -r '.since // 0' "$STATUS_FILE" 2>/dev/null || echo 0)
rec_ts=$(printf '%s' "$recent" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
rec_ms=0
if [ -n "$rec_ts" ]; then
  rec_s=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$rec_ts" +%s 2>/dev/null || echo 0)
  rec_ms=$((rec_s * 1000))
fi

if printf '%s' "$recent" | grep -qE 'token found|token still valid' && [ "$rec_ms" -gt "$since_ms" ]; then
  # Recovery happened after auth_required was set → stale flag. Reconcile atomically (temp + mv)
  # so we never clobber a concurrent daemon write mid-read.
  tmp=$(mktemp "${STATUS_FILE}.XXXXXX") || exit 0
  printf '{"status":"ok","reconciledBy":"reauth-watch","at":%s}\n' "$(($(date +%s) * 1000))" > "$tmp"
  mv -f "$tmp" "$STATUS_FILE"
  exit 0
fi

# Genuine re-auth needed. Notify at most once per hour.
mkdir -p "$CLAUDE_DIR/state" 2>/dev/null || true
STAMP="$CLAUDE_DIR/state/reauth-last-notified"
now=$(date +%s); last=0
[ -f "$STAMP" ] && last=$(tr -dc '0-9' < "$STAMP" 2>/dev/null); last=${last:-0}
if [ $((now - last)) -ge 3600 ]; then
  printf '%s' "$now" > "$STAMP"
  osascript -e 'display notification "Claude Code daemon needs re-auth — run: claude auth login" with title "Claude re-auth"' 2>/dev/null || true
  [ -x "$CLAUDE_DIR/hooks/play-tts.sh" ] && "$CLAUDE_DIR/hooks/play-tts.sh" "Claude needs re-authentication" 2>/dev/null || true
fi
exit 0
