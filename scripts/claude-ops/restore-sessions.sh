#!/usr/bin/env bash
# restore-sessions.sh — reopen parked Claude Code sessions after a laptop reboot.
#
# The Stop hook SAVES state every turn: a cwd-keyed handoff (~/.claude/handoffs/
# <cwd>.md, newest-wins) PLUS a per-session copy (handoffs/sessions/<cwd>__<sid>.md,
# one per session). This is the RESTORE half: it reopens one iTerm tab per parked
# session, `cd`s to its dir, and launches `claude -n <name>` with RESTORE_HANDOFF
# set so SessionStart injects THAT session's handoff — even when several sessions
# ran from the same folder (e.g. $HOME), which the cwd-keyed file alone collapses.
#
# By DEFAULT it restores only the RECENT BATCH — sessions you had open when you
# last stopped: the newest handoff and everything within WINDOW hours before it
# (default 18h). Shut the laptop last night, reboot, run restore — no flags.
#
# Usage:
#   restore-sessions.sh                # DRY RUN — print the recent batch, open nothing
#   restore-sessions.sh --go           # open the recent batch
#   restore-sessions.sh --hours 6      # tighten the batch window (default 18h)
#   restore-sessions.sh --days 3       # widen to a 3-day window
#   restore-sessions.sh --all          # every parked session, no window (cap still applies)
#   restore-sessions.sh --only a,b,c   # just these session names (window still applies;
#                                      #   add --all to take every match ever)
#   restore-sessions.sh -n 30          # raise the cap (default 25)
#   restore-sessions.sh --json         # machine-readable plan (for rohcna); opens nothing
#
# Layout: every session opens SIDE BY SIDE as an evenly-sized column in ONE iTerm
# window. iTerm takes 21+ columns fine (probed). Split them across windows with
# --panes N, or go back to one-tab-each with --tabs.
#   restore-sessions.sh --go --panes 4 # 4 columns per window, new window per group
#   restore-sessions.sh --go --tabs    # one tab per session (pre-2026-07 behaviour)
#
# Each pane launches with a brief prompt, so Claude opens by telling you where
# that session got to and what to do next instead of sitting on a raw handoff
# dump. --no-brief launches silent (cheaper; no tokens spent until you type).
set -uo pipefail

HANDOFF_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/handoffs"
PS_DIR="$HANDOFF_DIR/sessions"
WINDOW_HOURS=18
MAX_N=25
GO=0
JSON=0
ALL=0
LAYOUT=panes
PANES_PER_WINDOW=0   # 0 = all side by side in a single window
BRIEF=1
ONLY=""              # comma-separated session names; empty = no name filter

# Initial prompt handed to each restored pane. Single-quoted into the shell
# command, so it must contain NO apostrophes and no double quotes.
BRIEF_PROMPT='Restored session. Run: bash ~/.claude/scripts/session-recap.sh — then combine it with the handoff above and give me, in this order: RECAP (3-4 plain-English sentences on what this session was for and how it got here, written for someone who has forgotten it completely), WHERE IT GOT TO (2 lines), BLOCKED (1 line), NEXT (max 3 numbered actions with exact commands). Check branch and git status before trusting the handoff. Max 12 lines total. Do not start work until I reply.'

while [ $# -gt 0 ]; do
  case "$1" in
    --go)   GO=1 ;;
    --json) JSON=1 ;;
    --all)  ALL=1 ;;
    --tabs) LAYOUT=tabs ;;
    --no-brief) BRIEF=0 ;;
    --only) ONLY="${2:-}"; shift ;;
    --panes) LAYOUT=panes; PANES_PER_WINDOW="${2:-0}"; shift ;;
    --hours) WINDOW_HOURS="${2:-18}"; shift ;;
    --days)  WINDOW_HOURS=$(( ${2:-1} * 24 )); shift ;;
    -n|--max) MAX_N="${2:-25}"; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed '1d'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

case "$PANES_PER_WINDOW" in
  ''|*[!0-9]*) echo "--panes needs a non-negative integer (0 = all in one window)" >&2; exit 2 ;;
esac

[ -d "$HANDOFF_DIR" ] || { echo "No handoff store at $HANDOFF_DIR" >&2; exit 1; }

# Turn a repo path into a friendly, `claude -n`-safe slug.
clean_slug() {
  case "$1" in
    "$HOME")         echo "home" ;;
    "$HOME/.claude") echo "claude-config" ;;
    *) local b; b=$(basename "$1")
       b=$(printf '%s' "$b" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')
       [ -z "$b" ] && b="session"; echo "$b" ;;
  esac
}
path_of()  { grep -m1 '^- Path:' "$1" 2>/dev/null | sed -E 's/^- Path: `?//; s/`? *$//'; }
name_of()  { grep -m1 '^- Session:' "$1" 2>/dev/null | sed 's/^- Session: //'; }
kebab()    { printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-' | sed 's/--*/-/g; s/^-//; s/-$//'; }

# --- 1. Per-session entries (the un-collapsed source). mtime\tpath\tsid\tfile ---
ps_lines=""
if [ -d "$PS_DIR" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    p=$(path_of "$f"); p="${p/#\~/$HOME}"
    [ -n "$p" ] && [ -d "$p" ] || continue
    m=$(stat -f %m "$f" 2>/dev/null || echo 0)
    fn=$(basename "$f" .md); sid="${fn##*__}"
    ps_lines="${ps_lines}${m}	${p}	${sid}	${f}
"
  done <<< "$(ls -t "$PS_DIR"/*.md 2>/dev/null)"
fi
ps_lines=$(printf '%s' "$ps_lines" | grep -v '^$' || true)

# Paths already covered by per-session data (so we don't double-count the cwd file).
covered=$(printf '%s\n' "$ps_lines" | awk -F'\t' 'NF{print $2}' | sort -u)

# --- 2. Build the unified entry list: mtime\tpath\tname\tbasename\thfile\tsid ---
entries=""
# 2a. per-session entries (expanded; disambiguate name when a dir has >1 session)
if [ -n "$ps_lines" ]; then
  while IFS=$'\t' read -r m p sid f; do
    [ -z "$p" ] && continue
    n=$(printf '%s\n' "$ps_lines" | awk -F'\t' -v x="$p" '$2==x' | wc -l | tr -d ' ')
    sname=$(name_of "$f"); named=0
    if [ -n "$sname" ]; then
      slug=$(kebab "$sname"); named=1        # friendly name recorded at checkpoint
      [ -z "$slug" ] && { slug=$(clean_slug "$p"); named=0; }
    else
      slug=$(clean_slug "$p")                # fall back to cwd slug (+sid if the dir has siblings)
      [ "$n" -gt 1 ] && slug="${slug}-${sid:0:8}"
    fi
    entries="${entries}${m}	${p}	${slug}	$(basename "$p")	${f}	${sid}	${named}
"
  done <<< "$ps_lines"
fi
# 2b. cwd-keyed files for dirs with NO per-session data (older handoffs / back-compat)
while IFS= read -r f; do
  [ -z "$f" ] && continue
  p=$(path_of "$f"); p="${p/#\~/$HOME}"
  [ -n "$p" ] && [ -d "$p" ] || continue
  printf '%s\n' "$covered" | grep -qxF "$p" && continue
  m=$(stat -f %m "$f" 2>/dev/null || echo 0)
  sname=$(name_of "$f"); named=0
  if [ -n "$sname" ]; then slug=$(kebab "$sname"); named=1; [ -z "$slug" ] && { slug=$(clean_slug "$p"); named=0; }; else slug=$(clean_slug "$p"); fi
  entries="${entries}${m}	${p}	${slug}	$(basename "$p")	${f}	cwd:${p}	${named}
"
done <<< "$(ls -t "$HANDOFF_DIR"/*.md 2>/dev/null | grep -v '\.compact\.md$')"

entries=$(printf '%s' "$entries" | grep -v '^$' | sort -rn || true)

# One tab per SESSION, not per cwd. A session that took turns in several dirs has
# a handoff per dir, so it used to open as several panes. Keep its NEWEST handoff
# (freshest state + real working dir) but carry over the friendly `claude -n` name
# from whichever copy actually recorded one — checkpoint copies often have none.
entries=$(printf '%s\n' "$entries" | awk -F'\t' 'BEGIN{OFS="\t"}
  {
    sid = $6
    if (!(sid in base)) { base[sid] = $0; order[++k] = sid }
    if ($7 == 1 && !(sid in nm)) nm[sid] = $3
  }
  END {
    for (i = 1; i <= k; i++) {
      sid = order[i]; split(base[sid], fld, "\t")
      if (sid in nm) fld[3] = nm[sid]
      print fld[1], fld[2], fld[3], fld[4], fld[5], fld[6]
    }
  }')

# --- 2c. Optional name filter: --only app-a,project-a,app-b ---
if [ -n "$ONLY" ]; then
  entries=$(printf '%s\n' "$entries" | awk -F'\t' -v want="$ONLY" '
    BEGIN { n=split(tolower(want), a, /[, ]+/); for (i=1;i<=n;i++) if (a[i] != "") keep[a[i]]=1 }
    tolower($3) in keep')
  [ -z "$entries" ] && { echo "No parked sessions matched --only $ONLY" >&2; exit 1; }
  # Names get reused across days, so the time window still applies — pair with
  # --hours/--days to pin the batch, or --all to take every match ever.
fi
[ -z "$entries" ] && { echo "No parked sessions found." >&2; exit 0; }

# --- 3. Recent-batch window (from newest) + cap ---
if [ "$ALL" -eq 1 ]; then
  plan=$(printf '%s\n' "$entries" | head -n "$MAX_N")
  window_desc="all parked sessions"
else
  newest=$(printf '%s\n' "$entries" | head -1 | cut -f1)
  cutoff=$(( newest - WINDOW_HOURS * 3600 ))
  plan=$(printf '%s\n' "$entries" | awk -F'\t' -v c="$cutoff" '$1 >= c' | head -n "$MAX_N")
  window_desc="last ${WINDOW_HOURS}h of activity"
fi

# --- 4a. JSON output for callers (rohcna) ---
if [ "$JSON" -eq 1 ]; then
  # jq does the escaping: a quote or backslash in a path broke the hand-built JSON.
  while IFS=$'\t' read -r m p name base hfile sid; do
    [ -z "$p" ] && continue
    when=$(date -r "$m" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "")
    jq -cn --arg path "$p" --arg slug "$name" --arg name "$base" --arg when "$when" --arg handoff "$hfile" \
      '{path:$path, slug:$slug, name:$name, when:$when, handoff:$handoff}'
  done <<< "$plan" | jq -s .
  exit 0
fi

# --- 4b. Human plan ---
count=$(printf '%s\n' "$plan" | grep -c .)
echo "# Restore plan — $count session(s) ($window_desc, cap $MAX_N)"
echo
# Only warn about collapse if a HOME entry is a cwd-keyed fallback (no per-session
# data) — with per-session copies present, home no longer collapses.
if printf '%s\n' "$plan" | awk -F'\t' -v h="$HOME" '$2==h && $5 !~ /\/sessions\//' | grep -q .; then
  echo "⚠ A home-dir entry (\`$HOME\`) has no per-session copy (an older handoff)."
  echo "  Newer home sessions are now saved individually; this legacy one may still"
  echo "  represent several collapsed sessions."
  echo
fi
while IFS=$'\t' read -r m p name base hfile sid; do
  [ -z "$p" ] && continue
  when=$(date -r "$m" '+%m-%d %H:%M' 2>/dev/null || echo "?")
  echo "  • $when  $base  →  claude -n $name   ($p)"
done <<< "$plan"
echo

if [ "$LAYOUT" = tabs ]; then
  echo "Layout: one iTerm tab per session (--tabs)."
elif [ "$PANES_PER_WINDOW" -eq 0 ]; then
  echo "Layout: all $count side by side as columns in ONE window. (--panes N to split across windows, --tabs for tabs.)"
else
  wins=$(( (count + PANES_PER_WINDOW - 1) / PANES_PER_WINDOW ))
  echo "Layout: side-by-side columns, $PANES_PER_WINDOW per window = $wins window(s). (--panes 0 for one window, --tabs for tabs.)"
fi
if [ "$BRIEF" -eq 1 ]; then
  echo "Each pane opens with a where-was-I brief (costs tokens on launch; --no-brief to skip)."
fi
[ "$count" -gt 12 ] && echo "$count columns is narrow — tighten with --hours 6, cap with -n 8, or spread with --panes 6."
echo

if [ "$GO" -eq 0 ]; then
  echo "Dry run. Nothing opened. Re-run with --go to open these in iTerm."
  echo "Widen with --days N / --all, tighten with --hours N."
  exit 0
fi

# --- 5. Open the sessions ---
# Escape a shell command for embedding in an AppleScript string literal:
# backslash first, then double-quote. Without this the inner quotes of cd "..."
# terminate the string and osascript silently errors — the bug that made --go
# open nothing.
as_escape() {
  local s=${1//\\/\\\\}
  printf '%s' "${s//\"/\\\"}"
}
launch_cmd() { # path, name, handoff-file
  printf 'cd "%s" && RESTORE_HANDOFF=%s claude -n %s' "$1" "'$3'" "$2"
  [ "$BRIEF" -eq 1 ] && printf " '%s'" "$BRIEF_PROMPT"
  return 0
}

# --- 5a. One tab per session (--tabs) ---
open_tab() {
  local esc; esc=$(as_escape "$(launch_cmd "$1" "$2" "$3")")
  osascript 2>&1 <<OSA
tell application "iTerm"
  activate
  if (count of windows) = 0 then
    create window with default profile
    delay 2
    tell current session of current window to write text "$esc"
  else
    tell current window
      create tab with default profile
      delay 2
      tell current session of current tab to write text "$esc"
    end tell
  end if
end tell
OSA
}

# --- 5b. Side-by-side panes (default) ---
# CMDS[] holds the shell command for each pane in the current window group.
# emit_layout recursively bisects the pane range and splits vertically every time,
# so the sessions come out as evenly-sized COLUMNS. Bisection is what makes them
# even: a naive chain of splits off the last pane gives 50/25/12.5 slivers.
# A session that gets split is only written to at its own leaf, i.e. after all of
# its splits — so the emitted order is always split-then-run.
# Pass 1: emit only the splits, recording which AppleScript variable ends up
# holding each pane (VARS[i], left to right). Writing the commands is pass 2, and
# it must not start until every shell has had time to come up — see below.
emit_splits() { # var lo hi
  local var=$1 lo=$2 hi=$3
  if [ "$lo" -eq "$hi" ]; then VARS[$lo]=$var; return; fi
  local mid=$(( lo + (hi - lo + 1) / 2 - 1 ))
  local newvar="s$(( ++AS_COUNTER ))"
  printf '  tell %s\n    set %s to (split vertically with default profile)\n  end tell\n' \
    "$var" "$newvar"
  emit_splits "$var" "$lo" "$mid"
  emit_splits "$newvar" "$((mid + 1))" "$hi"
}
open_window_group() { # CMDS[] already populated, indices 0..n-1
  AS_COUNTER=1
  VARS=()
  local osa n=$(( ${#CMDS[@]} - 1 ))
  osa=$(
    printf 'tell application "iTerm"\n  activate\n  create window with default profile\n'
    printf '  set s1 to current session of current window\n  delay 1\n'
    emit_splits s1 0 "$n"
    # A freshly-created session will not reliably accept `write text` until its
    # shell has finished starting: the leading keystrokes get swallowed or
    # reordered, and the pane ends up running garbage (observed live: the command
    # arrived as `yocd "/home/..."`, i.e. `zsh: command not found: yocd`).
    # Splitting first and writing after a pause fixes it — verified.
    printf '  delay 2\n'
    local i
    for i in $(seq 0 "$n"); do
      printf '  tell %s to write text "%s"\n' "${VARS[$i]}" "$(as_escape "${CMDS[$i]}")"
    done
    printf 'end tell\n')
  # Debug: RS_PRINT_OSA=1 with --go prints the generated AppleScript (to stderr,
  # so it stays out of the caller's capture) and opens nothing.
  if [ -n "${RS_PRINT_OSA:-}" ]; then printf '%s\n' "$osa" >&2; return 0; fi
  osascript 2>&1 <<<"$osa"
}

opened=0 failed=0
if [ "$LAYOUT" = tabs ]; then
  while IFS=$'\t' read -r m p name base hfile sid; do
    [ -z "$p" ] && continue
    err=$(open_tab "$p" "$name" "$hfile")
    if [ $? -eq 0 ] && ! printf '%s' "$err" | grep -qi 'error'; then
      echo "  opened: $base  →  claude -n $name"; opened=$((opened+1))
    else
      echo "  FAILED: $base  →  claude -n $name  — ${err:-osascript error}"; failed=$((failed+1))
    fi
  done <<< "$plan"
  unit=tab
else
  CMDS=(); group_names=(); windows=0
  flush_group() {
    [ "${#CMDS[@]}" -eq 0 ] && return 0
    local err; err=$(open_window_group)
    if [ $? -eq 0 ] && ! printf '%s' "$err" | grep -qi 'error'; then
      windows=$((windows + 1))
      echo "  window $windows: ${group_names[*]}"
      opened=$((opened + ${#CMDS[@]}))
    else
      echo "  FAILED window: ${group_names[*]} — ${err:-osascript error}"
      failed=$((failed + ${#CMDS[@]}))
    fi
    CMDS=(); group_names=()
  }
  while IFS=$'\t' read -r m p name base hfile sid; do
    [ -z "$p" ] && continue
    CMDS+=("$(launch_cmd "$p" "$name" "$hfile")")
    group_names+=("$name")
    # PANES_PER_WINDOW=0 means never flush early — everything lands side by side
    # in one window.
    [ "$PANES_PER_WINDOW" -gt 0 ] && [ "${#CMDS[@]}" -ge "$PANES_PER_WINDOW" ] && flush_group
  done <<< "$plan"
  flush_group
  unit=pane
fi

echo
echo "Opened $opened $unit(s), $failed failed. Each pane injects its own handoff via RESTORE_HANDOFF."
[ "$failed" -gt 0 ] && echo "Failures above are real (no longer silenced) — check iTerm automation permission if all failed."
echo "Next: run /morning in any one of them for a single consolidated recap of all $opened."
exit 0
