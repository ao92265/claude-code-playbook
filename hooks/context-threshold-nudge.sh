#!/usr/bin/env bash
# context-threshold-nudge.sh — UserPromptSubmit hook.
#
# Two independent nudges, both fired from the same prompt hook:
#
#   1. CONTEXT %  — measured 2026-08-03: sessions ran to 200k-500k context
#      (auto-compact firing repeatedly) while core-rules said "reboot at ~50%".
#      Handoffs were already automatic (stop-handoff.sh), but NOTHING told the user
#      when to use one, so the rule never fired in practice.
#
#   2. SESSION AGE — added 2026-08-04: session-load-guard.sh runs only at
#      SessionStart, so it warns a NEW session about its stale neighbours; the
#      26h session itself was never told. core-rules caps a session at 4h.
#      Age is measured from the transcript file's birth time, which equals the
#      last /clear (verified: /clear starts a new transcript file).
#
# Each check fires ONCE per threshold per session, so it nudges instead of
# nagging. Age re-escalates every OMC_SESSION_MAX_H hours, so a very long
# session keeps being told. Non-blocking, always exit 0.
#
# Tune:    OMC_CTX_WINDOW (default 200000), OMC_SESSION_MAX_H (default 4)
# Disable: CLAUDE_SKIP_HOOKS=context-threshold-nudge
# Testing: OMC_AGE_TEST_S forces the session age in seconds (birth time cannot
#          be faked with touch, so this is the only way to exercise the tiers).
#          OMC_CTX_STATE_DIR redirects the once-per-tier state so fixtures do
#          not pollute the real session state.
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,context-threshold-nudge,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# The leaf "ctx-nudge" is always appended, so the prune below can only ever
# touch a directory this hook created — never a shared one someone points at.
STATE_DIR="${OMC_CTX_STATE_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state}/ctx-nudge"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
# The state dir never pruned itself and accumulated one file per session.
find "$STATE_DIR" -maxdepth 1 -type f -mtime +7 -delete 2>/dev/null || true

# Once-per-tier gate. $1 = state file suffix, $2 = tier. Exit 0 = fire now.
tier_is_new() {
  local file="$STATE_DIR/${SESSION:-unknown}$1" tier="$2" last
  last=$(cat "$file" 2>/dev/null || echo 0)
  case "$last" in ''|*[!0-9]*) last=0 ;; esac
  [ "$tier" -le "$last" ] && return 1
  # If the state cannot be written, stay silent rather than fire every prompt.
  printf '%s' "$tier" > "$file" 2>/dev/null || return 1
  return 0
}

# ---------------------------------------------------------------- context %

context_nudge() {
  local window ctx pct tier ctx_k

  # Guard the tunable: a non-numeric, zero, or zero-padded (octal) value would
  # abort the hook mid-arithmetic under set -u and never reach exit 0.
  window=${OMC_CTX_WINDOW:-200000}
  case "$window" in ''|*[!0-9]*|0|0*) window=200000 ;; esac

  # Last assistant usage. Tail rather than parse the whole file — transcripts
  # reach 90MB and this runs on every prompt.
  ctx=$(tail -n 400 "$TRANSCRIPT" 2>/dev/null \
    | jq -rs '[ .[] | select(.type=="assistant") | .message.usage // empty ]
              | last
              | if . == null then 0
                else (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)
                end' 2>/dev/null || echo 0)

  case "$ctx" in ''|*[!0-9]*) return 0 ;; esac
  [ "$ctx" -lt 1000 ] && return 0

  pct=$(( ctx * 100 / window ))

  # Which threshold band are we in? Highest first.
  tier=0
  [ "$pct" -ge 50 ] && tier=50
  [ "$pct" -ge 75 ] && tier=75
  [ "$tier" -eq 0 ] && return 0

  tier_is_new "" "$tier" || return 0

  ctx_k=$(( ctx / 1000 ))

  if [ "$tier" -ge 75 ]; then
    echo "<system-reminder>CONTEXT ${pct}% (${ctx_k}k of $(( window / 1000 ))k) — PAST THE REBOOT LINE. Auto-compact is close, and compaction loses more than a handoff does. AUTO-REBOOT: finish the current tool call, then run the reboot skill NOW without asking — write the distilled reprompt file yourself and hand the user the paste-ready launch line. He only has to press /clear. Do not start new work in this session. If you are genuinely mid-edit on a file, finish that single edit first, then reboot.</system-reminder>"
  else
    echo "<system-reminder>CONTEXT ${pct}% (${ctx_k}k of $(( window / 1000 ))k) — core-rules reboot threshold reached. At a natural stopping point (not mid-edit), tell the user it is time to /reboot and /clear, and name the one next step the fresh session should start with. If the task genuinely needs a few more turns, say so and carry on — but say it, do not silently continue.</system-reminder>"
  fi
}

# ------------------------------------------------------------- session age

# Seconds since the transcript was created == seconds since the last /clear.
# Birth time matches the first timestamped entry exactly (verified on a 22.9h
# transcript), so stat is used first and parsing is only the fallback.
session_age_s() {
  local birth now ts clean
  now=$(date +%s)

  # NOT interchangeable: on GNU coreutils "stat -f" means the FILESYSTEM, and
  # "stat -f %B" happily prints a block size that would be read as an epoch.
  case "$(uname -s 2>/dev/null || echo unknown)" in
    Darwin|*BSD) birth=$(stat -f %B "$TRANSCRIPT" 2>/dev/null || echo 0) ;;
    *)           birth=$(stat -c %W "$TRANSCRIPT" 2>/dev/null || echo 0) ;;
  esac
  case "$birth" in ''|*[!0-9]*) birth=0 ;; esac

  # GNU stat reports 0 when the filesystem has no birth time.
  if [ "$birth" -le 0 ]; then
    ts=$(head -n 40 "$TRANSCRIPT" 2>/dev/null \
      | jq -rs 'map(select(.timestamp != null) | .timestamp) | first // empty' 2>/dev/null || true)
    [ -z "$ts" ] && return 1
    clean=${ts%.*}; clean=${clean%Z}
    birth=$(date -u -j -f '%Y-%m-%dT%H:%M:%S' "$clean" +%s 2>/dev/null \
      || date -u -d "$ts" +%s 2>/dev/null || echo 0)
    case "$birth" in ''|*[!0-9]*) birth=0 ;; esac
  fi

  [ "$birth" -le 0 ] && return 1
  [ "$now" -le "$birth" ] && return 1
  echo $(( now - birth ))
}

age_nudge() {
  local age_s max_h tier h m

  age_s=${OMC_AGE_TEST_S:-}
  if [ -z "$age_s" ]; then
    age_s=$(session_age_s) || return 0
  fi
  case "$age_s" in ''|*[!0-9]*) return 0 ;; esac

  max_h=${OMC_SESSION_MAX_H:-4}
  case "$max_h" in ''|*[!0-9]*|0|0*) max_h=4 ;; esac

  h=$(( age_s / 3600 ))
  [ "$h" -lt "$max_h" ] && return 0

  # 4, 8, 12, 16... — re-escalates every max_h hours instead of going quiet.
  tier=$(( h / max_h * max_h ))
  tier_is_new ".age" "$tier" || return 0

  m=$(( age_s % 3600 / 60 ))

  if [ "$tier" -ge $(( max_h * 2 )) ]; then
    echo "<system-reminder>SESSION AGE ${h}h${m}m since the last /clear — WAY past the core-rules ${max_h}h session cap. AUTO-REBOOT: finish the current tool call, then run the reboot skill NOW without asking — write the distilled reprompt file yourself and hand the user the paste-ready launch line. He only has to press /clear. Do not start new work in this session. If you are genuinely mid-edit on a file, finish that single edit first, then reboot.</system-reminder>"
  else
    echo "<system-reminder>SESSION AGE ${h}h${m}m since the last /clear — past the core-rules ${max_h}h session cap. At a natural stopping point (not mid-edit), tell the user how long this session has been running and that it is /reboot and /clear time, and name the one next step the fresh session should start with. If the task genuinely needs a few more turns, say so and carry on — but say it once, do not repeat it every turn.</system-reminder>"
  fi
}

context_nudge
age_nudge
exit 0
