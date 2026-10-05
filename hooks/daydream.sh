#!/usr/bin/env bash
# Stop hook — "daydream" engine trigger.
#
# Why: you've built up a focused persistent memory (project spikes, content
# rules, blockers) that otherwise just sits there. This hook, when you go idle
# (Stop = assistant finished a turn), occasionally spawns a DETACHED, headless
# `claude --bare` pass that recombines those memories into novel ideas, scores
# them, and — if one is good enough — auto-forges a quick PRD via the prdforge
# skill. You wake up to fresh musings (surfaced by daydream-surface.sh on the
# next SessionStart) without ever asking for them.
#
# Cost control: fires at most once / 24h (sentinel written BEFORE spawn, so a
# crash still can't refire today). Child runs --model sonnet with subagents
# pinned to sonnet, and prdforge runs --quick → ~80-120k tok/day cap.
#
# Safety:
#   - Recursion: the child sets DAYDREAM_CHILD=1, so THIS hook short-circuits
#     when it fires on the child's own Stop. No fork-bomb.
#   - NOT --bare: --bare skips auth resolution, so the headless token is ignored
#     and the run dies "Not logged in" (verified). We load full settings — needed
#     so the /prdforge skill and its plugin agents resolve — and tame the
#     child's hooks via env instead: CLAUDE_DISABLE_HOOKS=1 quiets them;
#     CLAUDE_CODE_SUBAGENT_MODEL=sonnet satisfies require-agent-model.sh AND keeps
#     prdforge's subagents cheap; daydream-surface.sh self-guards on DAYDREAM_CHILD;
#     verify-gate no-ops (daydreams dir is not a JS/TS repo).
#   - Detached (nohup, subshell-backgrounded, stdin redirect) → this hook returns
#     in <1s and can never block the session. Child writes only under daydreams/.
#
# Kill switches:  CLAUDE_SKIP_HOOKS=daydream   (per-hook)   |   CLAUDE_DISABLE_HOOKS (global)
# Disable entirely: remove this hook from ~/.claude/settings.json Stop array.
set -uo pipefail

# Drain stdin (Stop hook receives JSON we don't need) so the producer never blocks.
cat >/dev/null 2>&1 || true

# --- kill switches & guards -------------------------------------------------
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,daydream,*) exit 0 ;; esac
[ -n "${CLAUDE_DISABLE_HOOKS:-}${DISABLE_OMC:-}" ] && exit 0
[ -n "${DAYDREAM_CHILD:-}" ] && exit 0          # never daydream from inside a daydream
command -v claude >/dev/null 2>&1 || exit 0

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DD="$CFG/daydreams"
STATE="$CFG/state"
ENGINE="$DD/engine-prompt.md"
MEMDIR="$CFG/projects/-Users-you/memory"
SENTINEL="$STATE/daydream-last.ts"
BETS_ENGINE="$DD/engine-bets-prompt.md"
BETS_SENTINEL="$STATE/daydream-bets-last.ts"   # weekly big-bets lane, own clock

# Nothing to do if the engine prompt or the memory corpus is missing.
[ -f "$ENGINE" ] || exit 0
[ -f "$MEMDIR/MEMORY.md" ] || exit 0

mkdir -p "$DD/logs" "$DD/prds" "$STATE" 2>/dev/null || true

# --- rate limit: daily lane once / 24h, bets lane once / 7 days -------------
now=$(date +%s)
due() {  # due <sentinel> <interval-seconds>
  local last=0
  [ -f "$1" ] && last=$(cat "$1" 2>/dev/null || echo 0)
  case "$last" in ''|*[!0-9]*) last=0 ;; esac
  [ $((now - last)) -ge "$2" ]
}
DAILY_DUE=0; due "$SENTINEL" 86400 && DAILY_DUE=1
BETS_DUE=0; [ -f "$BETS_ENGINE" ] && due "$BETS_SENTINEL" 604800 && BETS_DUE=1
[ "$DAILY_DUE$BETS_DUE" = "00" ] && exit 0

# --- headless auth: long-lived OAuth token from the macOS keychain ----------
# A fresh `claude` can't reuse the running app's hashed keychain creds, so it
# needs its own token (`claude setup-token`). We read it from the keychain at
# spawn time and NEVER from a file under ~/.claude (that dir is backed up to
# git/OneDrive — a plaintext token there could leak).
tok=$(security find-generic-password -a "$USER" -s daydream-oauth -w 2>/dev/null || true)
NEEDFLAG="$STATE/daydream-needs-token.flag"
if [ -z "$tok" ]; then
  # No token yet → can't auth headless. Do NOT claim the daily slot, so the
  # feature self-activates the moment you add the token. Leave a one-time hint.
  if [ ! -f "$NEEDFLAG" ]; then
    {
      echo
      echo "🌙 Daydream is wired but DORMANT — no headless token in the keychain yet."
      echo "  Activate (one time):"
      echo "    1) claude setup-token        # interactive, on your subscription"
      echo "    2) security add-generic-password -U -a \"\$USER\" -s daydream-oauth -w"
      echo "       (-w with no value prompts hidden, so the token never hits shell history)"
    } >> "$DD/digest-pending.md" 2>/dev/null || true
    : > "$NEEDFLAG" 2>/dev/null || true
  fi
  exit 0
fi
rm -f "$NEEDFLAG" 2>/dev/null || true   # token present → clear any stale hint

# Claim each slot BEFORE spawning so a rapid second Stop (or a spawn failure)
# can't double-fire. Fail-safe biases toward LESS spend.
# Full settings load (so /prdforge + its plugin agents resolve), hooks tamed by
# env: DAYDREAM_CHILD (no recursion), CLAUDE_DISABLE_HOOKS (quiet the child's hooks),
# CLAUDE_CODE_SUBAGENT_MODEL=sonnet (passes require-agent-model + cheap agents).
# Prompt via stdin redirect (NOT -p "$(cat ...)") so backticks/quotes in the
# prompt's code blocks are never shell-evaluated. Token via ENV (never argv).
spawn_lane() {  # spawn_lane <prompt-file> <model> <log-tag>
  local log="$DD/logs/run-$(date +%Y%m%d-%H%M%S)$3.log"
  (
    cd "$DD" 2>/dev/null || exit 0
    DAYDREAM_CHILD=1 \
    CLAUDE_DISABLE_HOOKS=1 DISABLE_OMC=1 \
    CLAUDE_CODE_SUBAGENT_MODEL=sonnet \
    CLAUDE_CODE_OAUTH_TOKEN="$tok" \
    nohup claude \
      --print \
      --model "$2" \
      --permission-mode bypassPermissions \
      --disallowedTools "AskUserQuestion" \
      --add-dir "$CFG" \
      < "$1" >> "$log" 2>&1 &
  ) >/dev/null 2>&1
}

if [ "$DAILY_DUE" = 1 ]; then
  printf '%s\n' "$now" > "$SENTINEL" 2>/dev/null && spawn_lane "$ENGINE" sonnet ""
fi
# Bets lane: weekly, top-tier model, because judgement is the whole job there.
if [ "$BETS_DUE" = 1 ]; then
  printf '%s\n' "$now" > "$BETS_SENTINEL" 2>/dev/null && spawn_lane "$BETS_ENGINE" opus "-bets"
fi

exit 0
