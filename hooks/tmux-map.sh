#!/usr/bin/env bash
# tmux-map.sh - SessionStart hook. Records where a session physically lives.
#
# The run referee sees sessions as transcript files. It has no idea which
# terminal any of them is sitting in, so it can observe a session but never
# talk to one. This hook closes that gap: it runs INSIDE the session, so it can
# read the tmux environment directly and write down the pane.
#
# session-rotate.sh reads this map to know where to type. A session started
# outside tmux writes nothing and is simply never rotated, which is the correct
# behaviour rather than a failure: there is no safe way to type into a bare
# iTerm tab from a background job (measured - launchd cannot drive AppleScript,
# it exits 0 having done nothing).
#
# State: ~/.claude/state/tmux-map/<session-id>.json
# Disable: CLAUDE_SKIP_HOOKS=tmux-map
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,tmux-map,*) exit 0 ;; esac

set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

# Not in tmux: nothing to record, and nothing downstream will touch this
# session. Silent by design, this is the common case during rollout.
[ -n "${TMUX:-}" ] || exit 0
[ -n "${TMUX_PANE:-}" ] || exit 0

. "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/lib/session-ident.sh" 2>/dev/null || true

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -n "$SESSION" ] || exit 0

MAP_DIR="${CLAUDE_TMUX_MAP_DIR:-$HOME/.claude/state/tmux-map}"
mkdir -p "$MAP_DIR" 2>/dev/null || exit 0

# The tmux socket matters as much as the pane: send-keys against the wrong
# server silently targets nothing. TMUX is "<socket>,<pid>,<index>".
SOCKET="${TMUX%%,*}"
# Human-readable name, for the ledger. Best effort - if tmux cannot answer we
# still record the pane, which is the part that has to be right.
TNAME=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo "")

# The claude process pid, resolved the SAME way reboot-stamp.sh resolves it, so
# the rotator can watch for that exact process's claim ticket rather than
# guessing from timestamps. Two sessions rebooting in the same minute must not
# be able to satisfy each other's wait.
IDENT_PID=""
command -v session_ident_pid >/dev/null 2>&1 && IDENT_PID=$(session_ident_pid 2>/dev/null || echo "")

TMP="$MAP_DIR/.$SESSION.$$"
jq -n \
  --arg session "$SESSION" \
  --arg pane "$TMUX_PANE" \
  --arg socket "$SOCKET" \
  --arg tmux_session "$TNAME" \
  --arg transcript "$TRANSCRIPT" \
  --arg cwd "$CWD" \
  --arg pid "$IDENT_PID" \
  --arg ts "$(date -Iseconds)" \
  '{session:$session, pane:$pane, socket:$socket, tmux_session:$tmux_session,
    transcript:$transcript, cwd:$cwd, pid:$pid, recorded:$ts}' \
  > "$TMP" 2>/dev/null && mv -f "$TMP" "$MAP_DIR/$SESSION.json" 2>/dev/null
rm -f "$TMP" 2>/dev/null

# Prune entries whose pane is gone, so the map does not silt up the way the
# open-question state dir did (1600+ files).
LIVE=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null || echo "")
if [ -n "$LIVE" ]; then
  for f in "$MAP_DIR"/*.json; do
    [ -f "$f" ] || continue
    p=$(jq -r '.pane // empty' "$f" 2>/dev/null || echo "")
    [ -n "$p" ] || continue
    printf '%s\n' "$LIVE" | grep -qxF "$p" || rm -f "$f"
  done
fi
exit 0
