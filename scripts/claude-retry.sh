#!/usr/bin/env bash
# claude-retry.sh — run the `claude` CLI and auto-relaunch it with exponential
# backoff when it dies from a TRANSIENT failure (API overload/529, 500/503,
# rate limit, network blip, Claude outage). Permanent failures (bad auth,
# no credit) are NOT retried — relaunching just burns the same error.
#
# Works where a model-invoked /retry skill can't: when Claude itself is down,
# the model isn't running to help, so this lives at the shell level.
#
# Usage:
#   claude-retry [any args you'd pass to `claude`]
#   claude-retry -p "summarize this repo"          # headless: scans output
#   claude-retry                                    # interactive TUI: retries on crash
#
# On a retry the conversation is resumed with `--continue` (unless you already
# passed --continue/-c/--resume), so you pick up where it died.
#
# Env knobs:
#   CLAUDE_RETRY_MAX     max retries after the first attempt   (default 5)
#   CLAUDE_RETRY_BASE    base backoff seconds, doubles each try (default 4)
#   CLAUDE_RETRY_CAP     max backoff seconds per wait           (default 120)
#   CLAUDE_BIN           path to the claude binary              (default: claude on PATH)
set -uo pipefail

MAX="${CLAUDE_RETRY_MAX:-5}"
BASE="${CLAUDE_RETRY_BASE:-4}"
CAP="${CLAUDE_RETRY_CAP:-120}"
BIN="${CLAUDE_BIN:-claude}"
LOG="$HOME/.claude/claude-retry.log"

command -v "$BIN" >/dev/null 2>&1 || { echo "claude-retry: '$BIN' not found on PATH" >&2; exit 127; }

# Transient = worth retrying. Matched case-insensitively against captured output.
TRANSIENT='overloaded|529|internal server error|500|503|service unavailable|rate.?limit|rate_limit|too many requests|timeout|timed out|econnreset|etimedout|enotfound|fetch failed|socket hang up|connection (reset|refused|error)|upstream|bad gateway|502|temporarily'
# Permanent = never retry, even on non-zero exit.
PERMANENT='invalid api key|invalid x-api-key|authentication_error|401|403|please run /login|credit balance|insufficient|quota|billing|permission denied'

# Is this an interactive TUI run? (no -p/--print, and stdout is a terminal)
interactive=1
for a in "$@"; do
  case "$a" in -p|--print) interactive=0 ;; esac
done
[ -t 1 ] || interactive=0

# Does the user already specify a resume flag? If so, don't add --continue.
has_resume=0
for a in "$@"; do
  case "$a" in -c|--continue|--resume|-r) has_resume=1 ;; esac
done

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" >>"$LOG"; }

attempt=0
while :; do
  # On a retry, add --continue so the conversation resumes (unless user set their own).
  extra=()
  if [ "$attempt" -gt 0 ] && [ "$has_resume" -eq 0 ]; then
    extra+=(--continue)
  fi

  # Safe empty-array expansion (macOS bash 3.2 + set -u).
  args=("${extra[@]+"${extra[@]}"}" "$@")

  if [ "$interactive" -eq 1 ]; then
    # TUI: run attached. Can't scan a live TUI, so classify on exit code only.
    "$BIN" "${args[@]}"
    code=$?
    captured=""
  else
    # Headless: capture combined output, echo it through, then classify on content.
    tmp="$(mktemp -t claude-retry.XXXXXX)"
    "$BIN" "${args[@]}" 2>&1 | tee "$tmp"
    code=${PIPESTATUS[0]}
    captured="$(cat "$tmp")"
    rm -f "$tmp"
  fi

  # Success.
  if [ "$code" -eq 0 ]; then
    [ "$attempt" -gt 0 ] && log "recovered after $attempt retr(y/ies)"
    exit 0
  fi

  # User aborted (Ctrl-C = 130, SIGTERM = 143). Don't fight the user.
  if [ "$code" -eq 130 ] || [ "$code" -eq 143 ]; then
    exit "$code"
  fi

  low="$(printf '%s' "$captured" | tr '[:upper:]' '[:lower:]')"

  # Permanent error in output → stop now.
  if [ -n "$low" ] && printf '%s' "$low" | grep -Eq "$PERMANENT"; then
    echo "claude-retry: permanent error (auth/credit) — not retrying." >&2
    log "permanent error, giving up (exit $code)"
    exit "$code"
  fi

  # Headless with output that has NO transient marker → treat as a real failure
  # (e.g. your prompt/tool genuinely failed), not an outage. Don't loop on it.
  if [ "$interactive" -eq 0 ] && [ -n "$low" ] && ! printf '%s' "$low" | grep -Eq "$TRANSIENT"; then
    echo "claude-retry: non-transient failure (exit $code) — not retrying." >&2
    log "non-transient failure, giving up (exit $code)"
    exit "$code"
  fi

  attempt=$((attempt + 1))
  if [ "$attempt" -gt "$MAX" ]; then
    echo "claude-retry: still failing after $MAX retries — giving up." >&2
    log "exhausted $MAX retries (exit $code)"
    exit "$code"
  fi

  # Exponential backoff, capped.
  wait=$((BASE * (1 << (attempt - 1))))
  [ "$wait" -gt "$CAP" ] && wait="$CAP"
  echo "claude-retry: transient failure (exit $code). Retry $attempt/$MAX in ${wait}s…" >&2
  log "transient failure (exit $code), retry $attempt/$MAX in ${wait}s"
  sleep "$wait"
done
