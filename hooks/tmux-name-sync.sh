#!/usr/bin/env bash
# Keep the tmux session name matching the Claude session name, so the iTerm tab
# bar reads "chatbot" instead of "cc-you-3".
#
# Runs on every prompt submit. Silent, never blocks, always exits 0: a rename
# failing must never cost the user a turn.
# CLAUDE_SKIP_HOOKS is a comma-separated list of hook names, not an on/off
# switch. Treating any value as "skip everything" silently disables this hook
# whenever an unrelated hook is being skipped.
case ",${CLAUDE_SKIP_HOOKS:-}," in *,tmux-name-sync,*) exit 0 ;; esac
[ -z "${TMUX:-}" ] && exit 0
command -v tmux >/dev/null 2>&1 || exit 0

CUR="$(tmux display-message -p '#{session_name}' 2>/dev/null)" || exit 0
[ -z "$CUR" ] && exit 0

# Walk up from this shell to the claude process that owns the pane, then read
# the name Claude gave itself from its own session file.
PANE_PID="$(tmux display-message -p '#{pane_pid}' 2>/dev/null)"
[ -z "$PANE_PID" ] && exit 0

NAME=""
PID="$PANE_PID"
for _ in 1 2 3; do
  F="$HOME/.claude/sessions/$PID.json"
  if [ -f "$F" ]; then
    NAME="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$F" | head -1)"
    [ -n "$NAME" ] && break
  fi
  KID="$(pgrep -P "$PID" 2>/dev/null | head -1)"
  [ -z "$KID" ] && break
  PID="$KID"
done

[ -z "$NAME" ] && exit 0
# Claude's own placeholder names carry no more meaning than the tmux default.
case "$NAME" in you-*|"") exit 0 ;; esac

# tmux names cannot contain a dot or colon, and must be unique.
SAFE="$(printf '%s' "$NAME" | tr '.:' '--' | tr -cd '[:alnum:]_-' | cut -c1-40)"
[ -z "$SAFE" ] && exit 0
[ "$SAFE" = "$CUR" ] && exit 0

TARGET="$SAFE"
if tmux has-session -t "=$TARGET" 2>/dev/null; then
  for n in 2 3 4 5 6 7 8 9; do
    if ! tmux has-session -t "=${SAFE}-${n}" 2>/dev/null; then TARGET="${SAFE}-${n}"; break; fi
  done
  [ "$TARGET" = "$SAFE" ] && exit 0
fi

tmux rename-session -t "$CUR" "$TARGET" 2>/dev/null
exit 0
