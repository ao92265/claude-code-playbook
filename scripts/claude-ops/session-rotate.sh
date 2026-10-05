#!/usr/bin/env bash
# session-rotate.sh <claude-session-uuid> [reason]
#
# Rotates one live session: makes it write its own reboot handoff, then clears
# it, so it comes back fresh and carries on. This is the piece that removes the
# last manual keystroke from the reboot loop.
#
# Everything else in that loop was already automatic. The referee measures
# context depth every 10 minutes; the Stop hook saves a handoff every turn;
# SessionStart re-injects it and auto-fires the resume prompt after a clear.
# Only /clear itself needed a human, because nothing could type into a session.
# tmux is that channel, and it is the only one that works from a background job
# (launchd cannot drive iTerm through AppleScript: it exits 0 having done
# nothing, measured).
#
# SAFETY. Typing blind into a terminal is dangerous in exactly one way that
# matters: Enter on a Claude Code permission prompt is an approval. A rotator
# that types without looking can authorise something the user never saw. Two guards,
# both mandatory:
#   1. Read the pane before typing. Any dialog on screen means defer, not type.
#   2. After typing the text and BEFORE sending Enter, read the pane again and
#      confirm the text actually landed in the input box. If it did not, we do
#      not know where the keystrokes went, so we stop and send nothing more.
# Guard 2 is what makes this safe against a dialog appearing in the gap between
# looking and typing. Deferring costs one 10-minute cycle. Approving something
# unseen costs an afternoon.
#
# Exit: 0 rotated · 2 not rotatable · 3 deferred, try later · 4 aborted mid-way
#
# Tune: ROTATE_REBOOT_WAIT (default 240s), ROTATE_COOLDOWN (default 1800s)
# Opt out one session: touch ~/.claude/state/rotate-optout/<pane-id-without-%>
set -uo pipefail

# The referee runs under launchd, whose PATH is /usr/bin:/bin:/usr/sbin:/sbin.
# tmux lives in /opt/homebrew/bin, so without this the rotator finds no tmux and
# exits "not rotatable" on every session, forever, without saying anything. It
# would have looked exactly like a feature that simply never fires.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

UUID="${1:-}"
REASON="${2:-context depth}"
[ -n "$UUID" ] || { echo "usage: session-rotate.sh <session-uuid> [reason]" >&2; exit 2; }

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MAP_DIR="${CLAUDE_TMUX_MAP_DIR:-$CLAUDE_DIR/state/tmux-map}"
REBOOTS="$CLAUDE_DIR/reboots"
PENDING_DIR="${OMC_REBOOT_STATE_DIR:-$CLAUDE_DIR/state}/reboot-pending"
OPTOUT_DIR="$CLAUDE_DIR/state/rotate-optout"
OQ_DIR="$CLAUDE_DIR/state/open-question"
LEDGER="$CLAUDE_DIR/run-referee/rotations.jsonl"
COOLDOWN_DIR="$CLAUDE_DIR/state/rotate-cooldown"
REBOOT_WAIT="${ROTATE_REBOOT_WAIT:-240}"
COOLDOWN="${ROTATE_COOLDOWN:-1800}"

mkdir -p "$COOLDOWN_DIR" "$(dirname "$LEDGER")" 2>/dev/null || true

# In-flight lock, keyed on the pane. Step 2 waits minutes for the handoff, and
# the referee wakes every 10 minutes: without this, a slow rotation would have a
# second rotator typing into the same terminal underneath it. The cooldown only
# starts after a SUCCESSFUL rotation, so it cannot cover this window.
LOCKDIR="$COOLDOWN_DIR/.inflight"
mkdir -p "$LOCKDIR" 2>/dev/null || true

ledger() {  # ledger <outcome> <detail>
  printf '{"ts":"%s","session":"%s","pane":"%s","reason":"%s","outcome":"%s","detail":"%s"}\n' \
    "$(date -Iseconds)" "$UUID" "${PANE:-}" "${REASON//\"/\'}" "$1" "${2//\"/\'}" \
    >> "$LEDGER" 2>/dev/null || true
}
bail() { ledger "$1" "$2"; [ -n "${3:-}" ] && echo "$2" >&2; exit "${4:-3}"; }

command -v tmux >/dev/null 2>&1 || bail "not-rotatable" "tmux not installed" 1 2
command -v jq   >/dev/null 2>&1 || bail "not-rotatable" "jq not installed" 1 2

MAP="$MAP_DIR/$UUID.json"
[ -f "$MAP" ] || bail "not-rotatable" "no tmux map: session is not in tmux" "" 2
PANE=$(jq -r '.pane // empty' "$MAP" 2>/dev/null)
SOCKET=$(jq -r '.socket // empty' "$MAP" 2>/dev/null)
IDENT_PID=$(jq -r '.pid // empty' "$MAP" 2>/dev/null)
MAP_CWD=$(jq -r '.cwd // empty' "$MAP" 2>/dev/null)
[ -n "$PANE" ] || bail "not-rotatable" "map has no pane" "" 2

TM=(tmux)
[ -n "$SOCKET" ] && TM=(tmux -S "$SOCKET")

# Pane still alive? A closed terminal is not a failure, just gone.
"${TM[@]}" list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qxF "$PANE" \
  || { rm -f "$MAP"; bail "not-rotatable" "pane $PANE no longer exists" "" 2; }

PANE_KEY="${PANE#%}"

LOCK="$LOCKDIR/$PANE_KEY"
if ! mkdir "$LOCK" 2>/dev/null; then
  # Stale lock from a rotator that died mid-wait: anything older than twice the
  # handoff timeout cannot still be running.
  age=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || date +%s) ))
  if [ "$age" -gt $(( REBOOT_WAIT * 2 )) ]; then
    rmdir "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null || bail "skipped" "rotation already in flight"
  else
    bail "skipped" "rotation already in flight for this pane"
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# --- Rails, cheapest first -------------------------------------------------
[ -f "$OPTOUT_DIR/$PANE_KEY" ] && bail "skipped" "session opted out of rotation"

# Cooldown is keyed on the PANE, not the session id: a clear starts a brand new
# session id, so a per-session cooldown would reset itself every rotation and
# could never stop a loop. The terminal is the thing that persists.
CD="$COOLDOWN_DIR/$PANE_KEY"
if [ -f "$CD" ]; then
  last=$(cat "$CD" 2>/dev/null || echo 0)
  now=$(date +%s)
  if [ $(( now - last )) -lt "$COOLDOWN" ]; then
    bail "skipped" "cooled down, rotated $(( (now - last) / 60 ))m ago"
  fi
fi

# Never rotate a session that is waiting on an answer. The reboot would throw
# away the very thing it is waiting for.
if [ -f "$OQ_DIR/$UUID.json" ]; then
  open_q=$(jq -r 'if (.open // .status // "") == "" then "" else "yes" end' "$OQ_DIR/$UUID.json" 2>/dev/null || echo "")
  [ -n "$open_q" ] && bail "skipped" "session has an open question pinned"
fi

# --- Guard 1: look at the screen before typing ------------------------------
# Any dialog means defer. The list is deliberately broad: a false defer costs
# ten minutes, a false Enter costs an unreviewed approval.
# Denylist: phrases that only ever appear while a dialog is waiting for an
# answer. "esc to cancel" belongs to a dialog; "esc to interrupt" belongs to a
# turn in progress and is fine, so the two must not be conflated.
DIALOG_RE='enter to confirm|enter to select|esc to cancel|do you want to|would you like to|no, and tell claude|yes, and (don.t ask|auto-accept)|select an option|trust this folder|quick safety check|\[y/n\]|\(y/n\)'

# Positive check: the input box must be on screen. Stronger than the denylist,
# because it does not depend on knowing every dialog's wording: a dialog
# REPLACES the input box, so its absence means something is waiting.
#
# The chevron alone proves nothing - it is both the input box prompt AND the
# selection cursor in a dialog. What separates them is structure: the input box
# is a chevron line sandwiched between two horizontal rules, and a dialog's
# options are not.
#
# The box must also be EMPTY. Typing appends to whatever is already there, so
# rotating a box holding "create step2.txt" would submit
# "create step2.txt/reboot" - garbage, sent on the user's behalf. Observed live:
# auto-mode parks its next action in the box, and the user's half-typed line lives
# there too.
#
# This is a defer, not a block: the box empties as soon as that text is
# submitted, and the referee comes back every ten minutes.
# An EMPTY input box is not "chevron then spaces": Claude Code pads it with a
# non-breaking space (verified by dumping the bytes of a live pane). Testing for
# ordinary whitespace therefore never matches, and every session looks occupied.
# The nbsp is passed in rather than written inline because the awk here does not
# take hex escapes in a pattern.
has_inputbox() {
  printf '%s' "$1" | awk -v nb="$(printf '\302\240')" '
    { line[NR] = $0 }
    END {
      for (i = 2; i < NR; i++) {
        if (line[i] ~ /^❯/ && line[i-1] ~ /^─────/ && line[i+1] ~ /^─────/) {
          s = line[i]
          sub(/^❯/, "", s)
          gsub(nb, " ", s)
          gsub(/[ \t]/, "", s)
          if (s == "") { exit 0 }   # box found, and empty
          exit 2                    # box found, but occupied
        }
      }
      exit 1                        # no box at all: a dialog is up
    }'
}

# Captured WITH escape sequences, because the attributes are the only way to
# tell Claude Code's dim suggestion placeholder from text a person actually
# typed. Both render as words sitting in the input box; only one of them is
# real. (Verified by dumping a live pane: the placeholder is wrapped in the
# dim attribute.) The placeholder spans are dropped, then all remaining escapes,
# leaving plain text for every check below.
pane_text() {
  "${TM[@]}" capture-pane -p -e -t "$PANE" 2>/dev/null \
    | perl -pe 's/\e\[2m.*?\e\[0m//g; s/\e\[[0-9;?]*[A-Za-z]//g' \
    | tr -d '\r'
}

SCREEN=$(pane_text)
[ -n "$SCREEN" ] || bail "skipped" "pane captured empty, not typing blind"
if printf '%s' "$SCREEN" | grep -qiE "$DIALOG_RE"; then
  bail "skipped" "a prompt or dialog is on screen, will retry next cycle"
fi
has_inputbox "$SCREEN"; BOX=$?
[ "$BOX" = "1" ] && bail "skipped" "no input box on screen, something is waiting for an answer"
[ "$BOX" = "2" ] && bail "skipped" "text already in the input box, not typing on top of it"

# --- Step 1: ask the session to write its reboot handoff --------------------
# Typed input queues while a turn is running, so there is no need to catch the
# session idle. Marker: the claim ticket for THIS claude process, which
# reboot-stamp.sh drops the moment a reboot file is written. Watching that pid
# rather than the reboots directory means two sessions rebooting in the same
# minute cannot satisfy each other's wait.
TICKET=""
TICKET_BEFORE=""
if [ -n "$IDENT_PID" ]; then
  TICKET="$PENDING_DIR/$IDENT_PID"
  [ -f "$TICKET" ] && TICKET_BEFORE=$(stat -f %m "$TICKET" 2>/dev/null || echo "")
fi
REBOOT_WATERMARK=$(date +%s)

# A handoff written earlier in THIS session still describes this session's work.
# /reboot deliberately declines to write a second copy when nothing has changed
# since the last one (observed live), so demanding a brand new file would stall
# every rotation of a session that had already handed off once. The session's
# own start is the honest cutoff: anything newer than that belongs to this
# session, anything older belongs to whatever ran here before.
MAP_TRANSCRIPT=$(jq -r '.transcript // empty' "$MAP" 2>/dev/null)
SESSION_BIRTH=""
[ -n "$MAP_TRANSCRIPT" ] && [ -f "$MAP_TRANSCRIPT" ] && \
  SESSION_BIRTH=$(stat -f %B "$MAP_TRANSCRIPT" 2>/dev/null || echo "")

# Is the /reboot turn finished? The transcript stops growing when the session
# goes idle. Only then is "it declined to write one" a real answer rather than
# a turn still in progress.
turn_done() {
  [ -n "$MAP_TRANSCRIPT" ] && [ -f "$MAP_TRANSCRIPT" ] || return 1
  local a b
  a=$(stat -f %m "$MAP_TRANSCRIPT" 2>/dev/null || echo 0)
  [ $(( $(date +%s) - a )) -ge 20 ] || return 1
  return 0
}

# Does this reboot file belong to this session's directory?
#
# Both spellings have to be accepted: /tmp is a symlink to /private/tmp on
# macOS, and the handoff stamps the path the shell reports while the map stores
# the resolved one. Matching only one spelling silently finds nothing, which
# reads as "the session never wrote a handoff". (Measured live: it did.)
owns() {
  [ -n "$MAP_CWD" ] || return 0
  grep -qF "$MAP_CWD" "$1" 2>/dev/null && return 0
  local stripped="${MAP_CWD#/private}"
  [ "$stripped" != "$MAP_CWD" ] && grep -qF "$stripped" "$1" 2>/dev/null && return 0
  grep -qF "/private$MAP_CWD" "$1" 2>/dev/null && return 0
  return 1
}

newest_owned_since() {  # newest_owned_since <epoch> -> path or nothing
  local cutoff="$1" f m
  for f in $(ls -t "$REBOOTS"/*.md 2>/dev/null | head -8); do
    m=$(stat -f %m "$f" 2>/dev/null || echo 0)
    [ "$m" -ge "$cutoff" ] || continue
    owns "$f" && { printf '%s' "$f"; return 0; }
  done
  return 1
}

# landed <text>: is <text> exactly what sits in the input box? Enter on a
# dialog is an approval, so this must read the BOX, not the screen: the chat
# above often already shows "/clear" or the resume message, and a whole-screen
# match would pass even if the keys went into a dialog. The box is a line
# starting with the chevron, directly under a horizontal rule, running down to
# the next rule. A long line wraps inside it in a narrow pane, so both sides are
# compared with all whitespace (and the box's non-breaking spaces) removed.
landed() {
  local want have
  want=$(printf '%s' "$1" | perl -CS -pe 's/[\s\x{a0}]//g')
  have=$(pane_text | perl -CS -ne '
    BEGIN { $in = 0; $prev = ""; $box = ""; $found = 0 }
    chomp;
    if ($in) {
      if (/^\x{2500}{5}/) { $in = 0; $found++ } else { $box .= $_ }
    } elsif (/^\x{276f}/ && $prev =~ /^\x{2500}{5}/) {
      $in = 1; ($box = $_) =~ s/^\x{276f}//;
    }
    $prev = $_;
    END { $box =~ s/[\s\x{a0}]//g; print $box if $found == 1 && !$in }')
  [ -n "$want" ] && [ "$have" = "$want" ]
}

send_line() {  # send_line <text> ; returns 1 if the text did not land
  local text="$1"
  "${TM[@]}" send-keys -t "$PANE" -l "$text" 2>/dev/null || return 1
  sleep 1
  # Guard 2: confirm the text is visibly sitting in the input box before Enter.
  # If it is not, we do not know where those keystrokes went, so we send
  # nothing further - no cleanup keys, no Enter. Stray text in an input box is
  # harmless and visible; a blind Enter is not.
  landed "$text" || return 1
  "${TM[@]}" send-keys -t "$PANE" Enter 2>/dev/null || return 1
  return 0
}

send_line "/reboot" || bail "aborted" "typed /reboot did not land in the input box, sent no Enter" 1 4

# --- Step 2: wait for the handoff to actually exist -------------------------
landed=""
deadline=$(( $(date +%s) + REBOOT_WAIT ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  sleep 5
  # Signal 1: the claim ticket. Precise, but it only fires when the reboot file
  # was written with the Write tool - /reboot sometimes writes it with a shell
  # heredoc instead, and the ticket hook is not on Bash. Measured live: the
  # handoff existed and no ticket did.
  if [ -n "$TICKET" ] && [ -f "$TICKET" ]; then
    m=$(stat -f %m "$TICKET" 2>/dev/null || echo "")
    if [ -n "$m" ] && [ "$m" != "$TICKET_BEFORE" ] && [ "$m" -ge "$REBOOT_WATERMARK" ]; then
      landed=$(cat "$TICKET" 2>/dev/null || echo "yes"); break
    fi
  fi
  # Signal 2: a reboot file written just now for this session's directory.
  # Always checked, never only as a fallback, because signal 1 misses the
  # shell-written case entirely. The directory match is what stops another
  # session's reboot, written in the same minute, from satisfying this wait.
  landed=$(newest_owned_since "$REBOOT_WATERMARK") && break
  # Signal 3: the turn has finished and a handoff from earlier in this session
  # is standing. That is /reboot saying the existing one is still accurate,
  # which is a completed reboot, not a failed one.
  if [ -n "$SESSION_BIRTH" ] && turn_done; then
    landed=$(newest_owned_since "$SESSION_BIRTH") && break
  fi
  landed=""
done

# A clear without a handoff is the one outcome that loses work. If the handoff
# never landed, stop here and leave the session alone: the referee's existing
# pause tier is still behind us as the backstop.
[ -n "$landed" ] || bail "aborted" "no reboot handoff after ${REBOOT_WAIT}s, did NOT clear" 1 4

# The claim ticket is what makes the fresh session pick up ITS OWN handoff
# rather than a sibling's. Write it here from what we know for certain (this
# pane's pid, this handoff), because the hook that normally writes it does not
# fire when /reboot used a shell command. Without this the next session falls
# back to a freshness scan, which is the exact bug the ticket was added to fix.
if [ -n "$IDENT_PID" ] && [ -f "$landed" ]; then
  mkdir -p "$PENDING_DIR" 2>/dev/null || true
  printf '%s\n' "$landed" > "$PENDING_DIR/$IDENT_PID" 2>/dev/null || true
fi

# --- Step 3: clear -----------------------------------------------------------
# Re-check the screen: the reboot turn may have ended on a permission prompt.
SCREEN=$(pane_text)
if printf '%s' "$SCREEN" | grep -qiE "$DIALOG_RE" || ! has_inputbox "$SCREEN"; then
  bail "aborted" "handoff written but the input box is not clear, did NOT clear" 1 4
fi
send_line "/clear" || bail "aborted" "handoff written but /clear did not land, sent no Enter" 1 4

date +%s > "$CD"

# --- Step 4: start it working again ------------------------------------------
# The fresh session comes back with the handoff already in context (verified
# live: it could name the task and the next step without reading a file), but it
# sits waiting. SessionStart asks for an automatic first turn and this build
# does not act on that request, so the last inch is done the same way as the
# rest: by typing.
#
# Skipped if the session is already working, so that a future build which does
# honour the automatic start does not get a second prompt on top of it.
RESUME_MSG="${ROTATE_RESUME_PROMPT:-Continue from the reboot handoff above. If it reports the work already finished, say so and stop, do not invent follow-up work.}"
if [ "${ROTATE_RESUME:-1}" != "0" ]; then
  resume_deadline=$(( $(date +%s) + 90 ))
  resumed=""
  while [ "$(date +%s)" -lt "$resume_deadline" ]; do
    sleep 5
    SCREEN=$(pane_text)
    printf '%s' "$SCREEN" | grep -qiE "$DIALOG_RE" && continue
    has_inputbox "$SCREEN"; BOX=$?
    [ "$BOX" = "0" ] || continue          # box not back yet, or occupied
    # Already working? Then the session started its own turn: leave it alone.
    if printf '%s' "$SCREEN" | grep -qiE "esc to interrupt|tokens · esc"; then
      resumed="already working"; break
    fi
    if send_line "$RESUME_MSG"; then resumed="prompted"; fi
    break
  done
  ledger "rotated" "handoff: $(basename "$landed"); resume: ${resumed:-not confirmed}"
  echo "rotated $UUID in pane $PANE ($REASON) - resume: ${resumed:-not confirmed}"
  exit 0
fi

ledger "rotated" "handoff: $(basename "$landed")"
echo "rotated $UUID in pane $PANE ($REASON)"
exit 0
