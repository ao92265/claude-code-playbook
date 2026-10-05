#!/usr/bin/env bash
# reap.sh - find (and optionally kill) dead detached tmux Claude sessions.
#
# Dead means ALL of: not attached, idle past the threshold, the pane is really
# running Claude, nothing typed at the prompt, not this session, not protected.
#
# Default run reports only. --kill does the killing.
set -uo pipefail
# The launchd job sets only PATH, so it runs in the C locale. There, sed, tr and
# grep treat ❯ and the no-break space Claude draws after it as raw bytes, the
# empty prompt reads as typed text, and every Claude session gets spared. Pin a
# UTF-8 locale so the scheduled run judges panes the way an interactive one does.
export LC_ALL=en_US.UTF-8

MINUTES=30
# A session detached one minute ago and a session abandoned an hour ago look
# identical to tmux: there is no last-detached timestamp to read. So a low
# --minutes cannot distinguish "orphaned" from "he just closed the window", and
# on 2026-09-09 a --minutes 1 run killed a session that was on screen moments
# before. Nothing under this floor is ever dead, whatever --minutes says.
# The env var exists so the self-test can lift it, not as a way to go lower.
MIN_IDLE="${REAP_MIN_IDLE_SECONDS:-300}"
DO_KILL=0
IGNORE_TYPED=0
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTECTED_FILE="$SKILL_DIR/protected.txt"

while [ $# -gt 0 ]; do
  case "$1" in
    --minutes) MINUTES="${2:-30}"; shift 2 ;;
    --kill)    DO_KILL=1; shift ;;
    --ignore-typed) IGNORE_TYPED=1; shift ;;
    -h|--help) echo "usage: reap.sh [--minutes N] [--kill] [--ignore-typed]"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

command -v tmux >/dev/null 2>&1 || { echo "tmux not installed"; exit 0; }
tmux list-sessions >/dev/null 2>&1 || { echo "No tmux server running. Nothing to reap."; exit 0; }

# The session we are sitting in. Only asked when inside tmux: outside it (the
# scheduled launchd run), display-message answers with the most recently used
# session instead of nothing, which would spare that session every run.
SELF=""
[ -n "${TMUX:-}" ] && SELF="$(tmux display-message -p '#{session_name}' 2>/dev/null || true)"

is_protected() {
  [ -f "$PROTECTED_FILE" ] || return 1
  local name="$1" line
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -z "$line" ] && continue
    # shellcheck disable=SC2254
    case "$name" in $line) return 0 ;; esac
  done < "$PROTECTED_FILE"
  return 1
}

NOW=$(date +%s)
THRESHOLD=$(( MINUTES * 60 ))
[ "$THRESHOLD" -lt "$MIN_IDLE" ] && THRESHOLD="$MIN_IDLE"
EFFECTIVE_M=$(( THRESHOLD / 60 ))
DEAD=(); DEAD_DESC=(); SPARED=()

while IFS='|' read -r NAME ATTACHED ACTIVITY; do
  [ -z "$NAME" ] && continue
  # #{session_activity} moves only on client key input, so a detached session
  # that is busy printing (an autonomous run, or session-rotate.sh typing via
  # send-keys) looks idle for days. Window activity moves on pane output, so
  # the idle clock is the newest of the two.
  for W in $(tmux list-windows -t "$NAME" -F '#{window_activity}' 2>/dev/null); do
    case "$W" in ''|*[!0-9]*) continue ;; esac
    [ "$W" -gt "$ACTIVITY" ] && ACTIVITY="$W"
  done
  IDLE=$(( NOW - ACTIVITY ))
  IDLE_M=$(( IDLE / 60 ))

  if [ "$NAME" = "$SELF" ]; then
    SPARED+=("$NAME|this session"); continue
  fi
  # Pick up the Claude session name while we are here: the name-sync hook
  # renames tmux sessions, so a protect list keyed only on the tmux name goes
  # stale the moment a bot session gets renamed.
  CLAUDE_NAME=""
  probe="$(tmux list-panes -t "$NAME" -F '#{pane_pid}' 2>/dev/null | head -1)"
  for _ in 1 2 3; do
    [ -z "$probe" ] && break
    f="$HOME/.claude/sessions/$probe.json"
    if [ -f "$f" ]; then
      CLAUDE_NAME="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -1)"
      [ -n "$CLAUDE_NAME" ] && break
    fi
    probe="$(pgrep -P "$probe" 2>/dev/null | head -1)"
  done

  if is_protected "$NAME" || { [ -n "$CLAUDE_NAME" ] && is_protected "$CLAUDE_NAME"; }; then
    SPARED+=("$NAME|on the protect list"); continue
  fi
  if [ "$ATTACHED" != "0" ]; then
    SPARED+=("$NAME|you are looking at it"); continue
  fi

  # Is the pane really Claude? Walk the pane's process tree, because the pane
  # command string is Claude's version banner, not a program name.
  PANE_PID="$(tmux list-panes -t "$NAME" -F '#{pane_pid}' 2>/dev/null | head -1)"
  IS_CLAUDE=0
  if [ -n "$PANE_PID" ]; then
    if ps -o command= -p "$PANE_PID" 2>/dev/null | grep -q '/claude\b\|[[:space:]]claude\b\|^claude\b'; then
      IS_CLAUDE=1
    else
      for kid in $(pgrep -P "$PANE_PID" 2>/dev/null); do
        if ps -o command= -p "$kid" 2>/dev/null | grep -q '/claude\b\|[[:space:]]claude\b\|^claude\b'; then
          IS_CLAUDE=1; break
        fi
      done
    fi
  fi
  if [ "$IS_CLAUDE" -eq 0 ]; then
    SPARED+=("$NAME|not a Claude session"); continue
  fi

  if [ "$IDLE" -lt "$THRESHOLD" ]; then
    if [ "$MINUTES" -lt "$EFFECTIVE_M" ] && [ "$IDLE" -ge $(( MINUTES * 60 )) ]; then
      # Say so out loud: otherwise a low --minutes looks like it was ignored.
      SPARED+=("$NAME|only idle ${IDLE_M}m, under the ${EFFECTIVE_M}m floor")
    else
      SPARED+=("$NAME|only idle ${IDLE_M}m")
    fi
    continue
  fi

  # Captured WITH escapes: the dim attribute is the only thing that tells
  # Claude's suggestion placeholder (❯ Try "fix typecheck errors") from text a
  # person typed, so shape-matching cannot do it. Same approach as
  # session-rotate.sh pane_text(). RAW keeps everything; PANE is plain text
  # with dim text kept (the busy and dialog hints may be dim); PROMPT_PANE also
  # drops the dim spans and is only used to read the ❯ row. The no-break space
  # Claude draws after ❯ becomes a plain space in both.
  RAW="$(tmux capture-pane -p -e -t "$NAME" 2>/dev/null || true)"
  NBSP="$(printf '\302\240')"
  PANE="$(printf '%s\n' "$RAW" | perl -pe 's/\e\[[0-9;?]*[A-Za-z]//g' | tr -d '\r' | sed "s/$NBSP/ /g")"
  PROMPT_PANE="$(printf '%s\n' "$RAW" | perl -pe 's/\e\[2m.*?\e\[0m//g; s/\e\[[0-9;?]*[A-Za-z]//g' \
                 | tr -d '\r' | sed "s/$NBSP/ /g")"

  # A turn still running is not dead, it is busy.
  if printf '%s\n' "$PANE" | grep -qiE 'esc to interrupt|tokens · esc'; then
    SPARED+=("$NAME|still working"); continue
  fi

  # A session sitting on a dialog (trust folder, permission ask, any menu) is
  # blocked on the user, not abandoned. Check this BEFORE looking for typed
  # text: menu rows use the same ❯ arrow as the input box, so the typed-text
  # test reads a highlighted menu option as if the user had typed it.
  # The plan-approval menu says none of those words, so also treat a ❯ row
  # that is a numbered option ("❯ 1. Yes, and switch to BYPASS") as a menu.
  if printf '%s\n' "$PANE" | grep -qiE 'enter to confirm|esc to cancel|do you want to|would you like to proceed|yes, (i trust|and don)' \
     || printf '%s\n' "$PANE" | grep -qE '^[[:space:]]*❯[[:space:]]*[0-9]+\.[[:space:]]'; then
    SPARED+=("$NAME|waiting on a dialog"); continue
  fi

  # Unsent text at the prompt means work in flight.
  TYPED="$(printf '%s\n' "$PROMPT_PANE" | grep -E '^[[:space:]]*(❯|>|│ >)' | tail -1 \
           | sed -E 's/^[[:space:]]*(❯|>|│ >)[[:space:]]*//' | tr -d '[:space:]')"
  # The dim placeholder hints are already gone (PROMPT_PANE). One more thing
  # sits on the ❯ row that nobody typed: the rotation script types its resume
  # line and can die before pressing Enter; that line comes from session-rotate.sh
  # (RESUME_MSG) and sessionstart-handoff.sh, which share this prefix. TYPED
  # is already space-stripped, so the prefix is too. A narrow pane wraps the
  # line early and leaves only a stub on the ❯ row, hence the both-ways test,
  # with a length floor so a bare "Continue" someone typed still counts.
  RESUME_PREFIX="Continuefromthereboothandoffabove."
  if [ "${TYPED#"$RESUME_PREFIX"}" != "$TYPED" ] \
       || { [ "${#TYPED}" -ge 15 ] && [ "${RESUME_PREFIX#"$TYPED"}" != "$RESUME_PREFIX" ]; }; then
    TYPED=""
  fi
  NOTE=""
  if [ -n "$TYPED" ]; then
    if [ "$IGNORE_TYPED" -eq 0 ]; then
      SPARED+=("$NAME|unsent text at the prompt"); continue
    fi
    # --ignore-typed only overrides THIS rule. Attached, protected, current
    # session and still-working all still spare, and they run before here.
    NOTE=" [had unsent text]"
  fi

  # Last meaningful line: skip blanks, box rules, the empty prompt, and the
  # statusline rows at the bottom, which otherwise win every time. The ❯ rows
  # go too: by now they hold only a placeholder or an unsent resume line, and
  # showing those reads as if someone typed them.
  LAST="$(printf '%s\n' "$PANE" | grep -vE '^[[:space:]]*$' \
          | grep -vE '^[[:space:]]*[─━│╭╰┃▔▁]+' \
          | grep -vE '^[[:space:]]*❯|^[[:space:]]*>[[:space:]]*$' \
          | grep -vE 'ctx:|sess:|thinking |shift\+tab|bg:|wk:|5h:|tools:|/rc$|\$[0-9]|⏵⏵|⏸' \
          | grep -vE '^[[:space:]]*idle [0-9]+[smhd][[:space:]]*$' \
          | tail -1 | sed -E 's/^[[:space:]]+//' | cut -c1-60)"
  DEAD+=("$NAME")
  DEAD_DESC+=("$NAME|${IDLE_M}m|${LAST:-(empty)}${NOTE}")
done < <(tmux list-sessions -F '#{session_name}|#{session_attached}|#{session_activity}' 2>/dev/null)

if [ "${#DEAD[@]}" -eq 0 ]; then
  echo "Nothing dead. No detached Claude session has been idle over ${EFFECTIVE_M}m."
else
  echo "DEAD (detached, idle >${EFFECTIVE_M}m, nothing pending):"
  printf '%s\n' "${DEAD_DESC[@]}" | awk -F'|' '{printf "  %-22s idle %-6s %s\n", $1, $2, $3}'
fi

if [ "${#SPARED[@]}" -gt 0 ]; then
  echo
  echo "SPARED:"
  printf '%s\n' "${SPARED[@]}" | awk -F'|' '{printf "  %-22s %s\n", $1, $2}'
fi

if [ "$DO_KILL" -eq 1 ] && [ "${#DEAD[@]}" -gt 0 ]; then
  echo
  for s in "${DEAD[@]}"; do
    if tmux kill-session -t "$s" 2>/dev/null; then echo "killed $s"; else echo "FAILED to kill $s"; fi
  done
  echo
  echo "Conversations are not lost. 'claude --resume' reopens any of them."
fi
