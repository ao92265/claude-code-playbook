#!/usr/bin/env bash
# ui-state-recorder.sh - PostToolUse. The passive half of the UI state gate.
#
# Why: ui-state-nudge.sh has existed since 2026-07-24 and only NUDGES. The
# align-dark saga still burned multiple sessions and roughly 15 commits because
# parity was judged under the wrong active theme. A nudge that can be read and
# ignored is not a gate. This records, ui-state-gate.sh blocks.
#
# It watches tool calls go past and stamps the session as "state asserted" when
# it sees the live theme, variant or flag actually being READ. Nothing here can
# be satisfied by typing a claim: the stamp needs a real query with a real
# response, which is the whole point.
#
# Silent always, exits 0 always. This is a recorder, not a gate.
#
# Disable: CLAUDE_SKIP_HOOKS=ui-state
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,ui-state,*) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

set -uo pipefail
INPUT=$(cat 2>/dev/null || true)
printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || exit 0

SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || true)
SID=$(printf '%s' "$SID" | tr -dc 'A-Za-z0-9_-'); SID=${SID:-default}

STATE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/ui-state"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# Everything the model sent in: the JS it ran, the command, the selector.
# Joined because the interesting field differs per tool.
# WHO is allowed to satisfy the gate. This used to accept any tool, so
# `grep -rn 'data-theme' src/` stamped the session and unlocked the gate without
# a browser ever being involved. Reading the string is not reading the state.
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)
SENT=$(printf '%s' "$INPUT" | jq -r '
  [ (.tool_input.code // ""), (.tool_input.command // ""), (.tool_input.script // ""),
    (.tool_input.expression // ""), (.tool_input.text // ""), (.tool_input.selector // "") ]
  | map(select(. != "")) | join(" ")' 2>/dev/null || true)
[ -n "$SENT" ] || exit 0

case "$TOOL" in
  mcp__claude-in-chrome__*) ;;                       # a real page, a real read
  Bash|bash)
    # The one non-browser path that is a genuine measurement: the headless
    # parity tool, which prints the live theme it actually rendered under.
    printf '%s' "$SENT" | grep -q 'theme-parity' || exit 0 ;;
  *) exit 0 ;;
esac

# A state QUERY, not a state mention. These are the reads that actually settle
# "which theme am I looking at": the attribute, the computed style, the media
# query, the root class list. Prose about dark mode does not match.
QUERY='data-theme|getComputedStyle|computedStyleMap|matchMedia|prefers-color-scheme|documentElement\.(getAttribute|classList|dataset)|colorScheme|activeTheme|currentTheme|theme-parity'
printf '%s' "$SENT" | grep -qiE "$QUERY" || exit 0

# The response has to carry a RESOLVED VALUE, not merely be non-empty. Echoing
# the string back satisfied the old check; a colour, a theme name or an explicit
# boolean is evidence that something rendered and was measured.
OUT=$(printf '%s' "$INPUT" | jq -r '
  (.tool_response // empty) as $r
  | if ($r|type) == "string" then $r
    elif ($r|type) == "object" then
      ([$r.stdout // "", $r.stderr // "", $r.output // "", ($r.content // "" | tostring),
        ($r.result // "" | tostring)] | map(select(. != "")) | join("\n"))
    else "" end' 2>/dev/null || true)
[ -n "$(printf '%s' "$OUT" | tr -d '[:space:]')" ] || exit 0
RESOLVED='rgba?\(|hsla?\(|#[0-9a-fA-F]{3,8}\b|\b(true|false)\b|"(dark|light)"|:[[:space:]]*(dark|light)\b|theme=(dark|light)|\b[0-9]+(\.[0-9]+)?px\b'
printf '%s' "$OUT" | grep -qE "$RESOLVED" || exit 0

{
  printf 'at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'tool=%s\n' "$TOOL"
  printf 'query=%s\n' "$(printf '%s' "$SENT" | tr -d '\n' | cut -c1-300)"
} > "$STATE_DIR/asserted-${SID}" 2>/dev/null || true

# Keep the dir bounded. Session stamps are worthless after a fortnight.
find "$STATE_DIR" -type f -mtime +14 -delete 2>/dev/null || true
exit 0
