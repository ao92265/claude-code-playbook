#!/usr/bin/env bash
# matcha-surface - UserPromptSubmit hook. Two jobs, both about not making you
# remember anything:
#   1. Deliver any Matcha review that finished since the last prompt.
#   2. Warn when the subscription window is nearly spent, and say what to do.
exec 2>/dev/null
[[ -n "$CLAUDE_SKIP_HOOKS" && "$CLAUDE_SKIP_HOOKS" == *matcha* ]] && exit 0

STATE="$HOME/.claude/.matcha-review"
mkdir -p "$STATE"

# --- 1. finished reviews -------------------------------------------------
CWD="$(pwd)"
if REPO="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)"; then
  KEY="$(printf '%s' "$REPO" | shasum | cut -c1-12)"
  F="$STATE/$KEY.findings"
  SEEN="$STATE/$KEY.seen"
  if [[ -f "$F" ]] && { [[ ! -f "$SEEN" ]] || [[ "$F" -nt "$SEEN" ]]; }; then
    BODY="$(cat "$F")"
    if [[ -n "$BODY" && "$BODY" != *CLEAN* ]]; then
      printf '%s\n' "MATCHA SECOND REVIEW of the working diff in $(basename "$REPO"). Independent reader, read only, no edits made."
      printf '%s\n' "VISIBILITY IS MANDATORY: the user cannot see this text. Open your very next reply to them with a line that starts 'Matcha reviewed the diff:' and give them the verdict and what you are doing about it. Do not silently absorb it, and do not defer it to a later turn."
      printf '%s\n' "Treat every bullet as a claim to verify against the code first. Say which ones held up and which did not."
      printf '%s\n' "$BODY"
    fi
    touch "$SEEN"
  fi
fi

# --- 2. subscription headroom -------------------------------------------
python3 - <<'PY'
import json, os, time
p = os.path.expanduser("~/.claude/usage-history.jsonl")
try:
    if time.time() - os.path.getmtime(p) > 1800:
        raise SystemExit
    with open(p, "rb") as fh:
        fh.seek(max(0, os.path.getsize(p) - 4000))
        last = fh.read().decode("utf-8", "replace").strip().splitlines()[-1]
    d = json.loads(last)
    five = d.get("five_hour", {}).get("used_percentage", 0)
    week = d.get("seven_day", {}).get("used_percentage", 0)
except Exception:
    raise SystemExit

if week >= 99 or five >= 99:
    print(
        "MATCHA TAKEOVER ARMED: subscription at %d%% of the 5 hour window and %d%% of the week. "
        "When this session hits the wall it will relaunch itself on Matcha and carry on, so do "
        "not warn the user that work is about to be lost. Route everything you can through "
        "~/.claude/scripts/matcha-run.sh now rather than spending the last of the window here. "
        "Tell him once, in one line, that the takeover is armed." % (five, week)
    )
elif week >= 90 or five >= 85:
    print(
        "MATCHA OFFLOAD: subscription at %d%% of the 5 hour window and %d%% of the week. "
        "Push heavy or bulk work off it now: run it through ~/.claude/scripts/matcha-run.sh "
        "(the matcha skill) instead of doing it here or spawning a subagent. "
        "That spend lands on the Harris account, not the user's limit. "
        "Keep judgment and orchestration in this session." % (five, week)
    )
PY
exit 0
