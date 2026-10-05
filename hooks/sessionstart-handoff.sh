#!/usr/bin/env bash
# SessionStart hook — re-inject the last handoff so a FRESH session resumes clean.
#
# Why: this is the other half of the "don't resume the bloated session" model.
# You open a brand-new `claude` in the worktree; this hook prints the compact
# handoff to stdout, which Claude Code adds to the new session's context. You get
# oriented in ~40 lines instead of reloading a 6 MB transcript.
#
# Reads the central store written by stop-handoff.sh / precompact-handoff.sh, plus
# a curated SESSION_NOTES.md (from the /handoff skill) if one exists in the repo.
# Skips on `resume` (that path already restores the conversation). Always exits 0.
set -uo pipefail

input=$(cat 2>/dev/null || true)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -z "$cwd" ] && cwd="$PWD"
source_kind=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null || true)

# On a real --resume the full conversation is already restored; don't double up.
[ "$source_kind" = "resume" ] && exit 0

# --- Structured output --------------------------------------------------------------------
# Everything below still `echo`s as it always did, but stdout is redirected into a buffer and
# emitted once at the end as a SessionStart JSON payload. Plain stdout can only ever supply
# context; the JSON form additionally carries `sessionTitle` (renames the session) and
# `initialUserMessage` (starts the first turn with no typing), which is what makes
# `/reboot` -> `/clear` finish the job instead of leaving an idle, unnamed session.
#
# Buffering rather than rewriting every echo: the alternative is threading a variable through
# a dozen branches and three early exits, and the trap covers `exit` from anywhere.
exec 3>&1
BODY=$(mktemp "${TMPDIR:-/tmp}/handoff-body.XXXXXX" 2>/dev/null) || BODY=""
SESSION_TITLE=""
INITIAL_MSG=""
SYSTEM_MSG=""
UNPROVEN_FILE=""

_emit() {
  exec 1>&3 3>&- 2>/dev/null || true
  if [ -n "$BODY" ] && [ -s "$BODY" ]; then
    # Strip C0 control bytes and DEL (tab and newline survive) before the body leaves
    # this hook. Handoff bodies carry the model's own last action and the user's recent
    # asks verbatim, so an indirect injection upstream could plant an ANSI or OSC 52
    # sequence that the receiving pane interprets. jq does not save us here: it encodes
    # ESC as  in transit and the consumer decodes it straight back to a real byte.
    # Any failure leaves BODY untouched, because a degraded filter beats a lost handoff.
    if tr -d '\000-\010\013-\037\177' < "$BODY" > "${BODY}.filtered" 2>/dev/null; then
      mv -f -- "${BODY}.filtered" "$BODY" 2>/dev/null || rm -f -- "${BODY}.filtered" 2>/dev/null || true
    else
      rm -f -- "${BODY}.filtered" 2>/dev/null || true
    fi
    _e_json=""
    if command -v jq >/dev/null 2>&1; then
      # --rawfile, not --arg: reboot bodies are markdown full of backticks, quotes, code
      # fences and newlines, and jq is what guarantees they survive as a JSON string.
      _e_json=$(jq -n --rawfile ctx "$BODY" --arg title "$SESSION_TITLE" --arg initial "$INITIAL_MSG" \
        --arg sysmsg "$SYSTEM_MSG" \
        '{hookSpecificOutput: ({hookEventName: "SessionStart", additionalContext: $ctx}
           + (if $title   == "" then {} else {sessionTitle: $title} end)
           + (if $initial == "" then {} else {initialUserMessage: $initial} end))}
          + (if $sysmsg == "" then {} else {systemMessage: $sysmsg} end)' 2>/dev/null) || _e_json=""
    fi
    # No jq, an old jq without --rawfile, or any other failure: fall back to the plain text
    # this hook emitted before. Half-formed JSON would land in the user's context verbatim,
    # so degrading to "context only, no rename" is the only acceptable failure mode.
    if [ -n "$_e_json" ]; then printf '%s\n' "$_e_json"; else cat "$BODY" 2>/dev/null; fi
  fi
  [ -n "$BODY" ] && { rm -f -- "$BODY" 2>/dev/null || true; }
  [ -n "$UNPROVEN_FILE" ] && { rm -f -- "$UNPROVEN_FILE" 2>/dev/null || true; }
  return 0
}
trap _emit EXIT
[ -n "$BODY" ] && exec 1>"$BODY"

# Explicit restore: restore-sessions.sh launches each tab with RESTORE_HANDOFF set
# to the exact per-session handoff to load. This is how a home-dir session gets ITS
# OWN handoff instead of the newest-wins cwd file. When set, inject that and stop
# (no home nudge — this launch is deliberate).
#
# Startup ONLY. The variable sits on the claude process, so it outlives the session it
# was meant for: every later /clear in that pane fired this branch again, replayed the
# morning's restore file and exited before the pid claim ticket below. A /reboot ->
# /clear in a restored pane therefore resumed the wrong session (2026-09-23: the project-f
# pane came back as the outlook one). On clear and compact the ticket and the normal
# per-session lookup are the truth; the restore file is hours stale by then.
if [ -n "${RESTORE_HANDOFF:-}" ] && [ -f "$RESTORE_HANDOFF" ] \
   && { [ "$source_kind" = "startup" ] || [ -z "$source_kind" ]; }; then
  echo "=== Restored session handoff ==="
  cat "$RESTORE_HANDOFF" 2>/dev/null || true
  echo
  echo "_Resume from the above. Verify branch/dirty state before acting; don't trust it blindly._"
  exit 0
fi

# Session identity: name via stdin > env > the native registry (~/.claude/sessions/
# <pid>.json). Hook stdin never actually carries a name (hooks reference, v2.1.223), so
# before the registry lookup a `claude -n` / /rename name was invisible here — named
# home sessions were nudged as "unnamed" and keyed into the shared slot.
# shellcheck source=lib/session-ident.sh
. "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/lib/session-ident.sh"
sname=$(session_ident_resolve "$input")
cwd_top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)

# Nudge — only for the case that still collides on the every-turn handoff: an UNNAMED
# session outside a repo shares a single cwd-keyed file, newest wins. (Its /reboot is
# safe regardless since the pid claim ticket, but the running stop-handoff state is not.)
if [ -z "$cwd_top" ] && [ -z "$sname" ]; then
  echo "=== ⚠ Unnamed session outside a repo — handoff will be overwritten ==="
  echo "Handoffs are keyed by repo+branch, or by folder+session-name. This session has"
  echo "neither, so it shares one handoff with every other unnamed session in $cwd and"
  echo "only the newest survives a reboot. Fix either way: \`cd\` into the repo, or"
  echo "relaunch with \`claude -n <name>\`. Naming it is enough — you can stay here."
  echo
fi

HANDOFF_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/handoffs"
# shellcheck source=lib/handoff-key.sh
. "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/lib/handoff-key.sh"
slug=$(handoff_key "$cwd" "$sname")
# Read side accepts every key format this hook has ever written, so a key change never
# orphans a handoff: current (hashed, per-session inside repos since 2026-08-12), the
# nameless repo+branch key that preceded it, the short-lived un-hashed one from 341c058,
# and the original cwd slug. Writes always use `slug`.
#
# The two historical formats are ambiguous BY DESIGN — they are what the hashed key was
# introduced to replace. Two repos named Scheduler share "Scheduler--main"; every named
# session in $HOME shares the legacy key. So a historical candidate is only accepted after
# handoff_owns proves, from the file's own recorded path/branch/session, that it belongs to
# this session. Reading a sibling's handoff would be worse than reading none: it looks like
# your own context and gets acted on.
inter=$(handoff_intermediate_key "$cwd" "$sname")
legacy=$(handoff_legacy_key "$cwd")
# Nameless repo+branch key: the write key of every repo session before 2026-08-12 and of
# unnamed repo sessions still. A NAMED repo session now writes under a per-session key, so
# it must read this one as a fallback or everything written before the change is orphaned.
# Ambiguous by definition (all sessions in the repo+branch share it), hence ownership-proved
# below like the other historical formats. For unnamed sessions it equals `slug` and the
# loop's dedup guard skips it.
shared=$(handoff_repo_shared_key "$cwd")

handoff_pick() { # handoff_pick <suffix> -> newest owned candidate, or nothing
  _hp_sfx=$1
  _hp_best=""
  # Current key first: it is unambiguous by construction, so it needs no ownership proof.
  _hp_f="$HANDOFF_DIR/${slug}${_hp_sfx}"
  [ -f "$_hp_f" ] && _hp_best="$_hp_f"
  for _hp_k in "$shared" "$inter" "$legacy"; do
    [ -n "$_hp_k" ] || continue
    [ "$_hp_k" != "$slug" ] || continue
    _hp_f="$HANDOFF_DIR/${_hp_k}${_hp_sfx}"
    [ -f "$_hp_f" ] || continue
    if handoff_owns "$_hp_f" "$cwd" "$sname"; then
      if [ -z "$_hp_best" ] || [ "$_hp_f" -nt "$_hp_best" ]; then _hp_best="$_hp_f"; fi
    else
      # Exists under a key this session could plausibly have used, but nothing in the file
      # proves it. Record it as a pointer rather than injecting it or dropping it —
      # everything written before 2026-08-05 lacks an identity header, and guessing is how
      # one session ends up acting on another's context.
      #
      # Via a file, not a variable: handoff_pick is called in a command substitution, so
      # anything assigned in here dies with the subshell.
      [ -n "$UNPROVEN_FILE" ] && { printf '%s\n' "$_hp_f" >> "$UNPROVEN_FILE" 2>/dev/null || true; }
    fi
  done
  printf '%s' "$_hp_best"
}

# Empty, never /dev/null, on mktemp failure: the cleanup trap below would then have run
# `rm -f /dev/null` on every session start. Harmless as this user on macOS (root owns it)
# and catastrophic anywhere it succeeds. Every use of this variable is guarded instead, so
# a failed mktemp just means the pointer list is skipped for that session.
UNPROVEN_FILE=$(mktemp "${TMPDIR:-/tmp}/handoff-unproven.XXXXXX" 2>/dev/null) || UNPROVEN_FILE=""
# Cleanup lives in _emit's EXIT trap now — a second `trap ... EXIT` here would replace it and
# the whole payload would be silently dropped.

live=$(handoff_pick ".md")
compact=$(handoff_pick ".compact.md")
: "${live:=$HANDOFF_DIR/${slug}.md}"
: "${compact:=$HANDOFF_DIR/${slug}.compact.md}"
notes="$cwd/SESSION_NOTES.md"

# --- Rich /reboot handoff -------------------------------------------------------------
# Everything above is written mechanically every turn: it orients a fresh session but does
# not resume it. The actual reprompt is what the /reboot skill writes to ~/.claude/reboots/
# (2-13 KB, vs ~500 bytes here). Loading it at session start is what collapses
# `/reboot -> /clear -> /resume` into `/reboot -> /clear`.
#
# Same ownership bar as the rest of this hook, for the same reason: 179 of the 181 files in
# that directory predate any identity header, and injecting another session's reprompt is
# worse than injecting none — it reads as your own plan and gets executed. Unproven files
# fall through to the "may be yours" pointer list below rather than being loaded or dropped.
REBOOT_DIR="${OMC_REBOOT_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/reboots}"
REBOOT_STATE_DIR="${OMC_REBOOT_STATE_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state}/reboot-consumed"
REBOOT_MAX_LINES=${OMC_REBOOT_MAX_LINES:-400}
REBOOT_MAX_AGE_DAYS=${OMC_REBOOT_MAX_AGE_DAYS:-7}
reboot=""
_rb_marker=""
_rb_maybe=""
_rb_demoted=""

# Claim ticket first — the deterministic path. reboot-stamp.sh keys a ticket by the
# claude process pid at /reboot time; the process survives /clear, so finding our own
# pid's ticket proves same-terminal continuity with no name and no ambiguity. This is
# what makes /reboot -> /clear reliable for the one case the identity header cannot
# cover (unnamed session outside a repo), and it wins over the scan everywhere else too
# (renamed sessions, two reboots in one folder, sibling races).
#
# Same consume discipline as the scan: without a session_id this is a probe, so it may
# look but not spend — the ticket survives for the real /clear. With a session_id the
# ticket is deleted whether or not it was usable: stale tickets must not linger.
_rb_sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
PENDING_DIR="${OMC_REBOOT_STATE_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state}/reboot-pending"
_rb_pid=$(session_ident_pid)
if [ -n "$_rb_pid" ] && [ -f "$PENDING_DIR/$_rb_pid" ]; then
  _rb_claim=$(head -1 "$PENDING_DIR/$_rb_pid" 2>/dev/null || true)
  [ -n "$_rb_sid" ] && rm -f -- "$PENDING_DIR/$_rb_pid" 2>/dev/null
  # The ticket must point into the reboot store and at a fresh file — a claim is a
  # pointer, not a proof of content, so it gets the same freshness bar as the scan.
  case "$_rb_claim" in
    "$REBOOT_DIR"/*.md)
      if [ -f "$_rb_claim" ] && [ -z "$(find "$_rb_claim" -mtime +"$REBOOT_MAX_AGE_DAYS" 2>/dev/null)" ]; then
        reboot="$_rb_claim"
      fi
      ;;
  esac
fi

if [ -z "$reboot" ] && [ -d "$REBOOT_DIR" ]; then
  # This directory holds 181 files and grows daily, and the hook runs on EVERY session
  # start, so the scan is built around forking as few processes as possible. The first cut
  # of this block cost 0.7s (a `find` per file for freshness, then a `sed` per file inside
  # handoff_owns); batching both into single calls brought it under 0.1s.
  #
  # One find for the freshness window — a week-old reboot is stale intent, not a resume
  # point — then one `ls -t` to order newest-first. xargs preserves argument order, so
  # everything downstream stays in that order.
  _rb_cands=$(find "$REBOOT_DIR" -maxdepth 1 -type f -name '*.md' -mtime -"$REBOOT_MAX_AGE_DAYS" -print0 2>/dev/null \
              | xargs -0 ls -t 2>/dev/null | head -40)

  # One grep to split the candidates by whether they carry an identity header at all.
  # Nearly every file here predates the header, and this discards all of them for the cost
  # of a single process instead of a sed fork each inside handoff_owns.
  _rb_headed=""
  [ -n "$_rb_cands" ] && _rb_headed=$(printf '%s\n' "$_rb_cands" | tr '\n' '\0' \
                                      | xargs -0 grep -l -- '^- Path: `' 2>/dev/null || true)

  # Ownership is only ever asked of header-bearing files, newest first.
  #
  # Except: outside a repo, a candidate with no "- Session:" line is claimable by EVERY
  # unnamed session in that folder — handoff_owns compares empty against empty and says
  # yes to all of them. That is the steal: with ~10 live sessions, a sibling's startup
  # would consume the one-shot reboot between the owner's /reboot and /clear. The real
  # owner is served by the pid claim ticket above, so the scan demotes these to the
  # "may be yours" pointer list instead of injecting (and never consumes them). Repo
  # candidates are untouched: there the path+branch comparison does prove the worktree.
  while IFS= read -r _rb_f; do
    { [ -n "$_rb_f" ] && [ -f "$_rb_f" ]; } || continue
    if [ -z "$cwd_top" ] && ! grep -q '^- Session: ' "$_rb_f" 2>/dev/null; then
      _rb_demoted="${_rb_demoted}${_rb_f}
"
      continue
    fi
    if handoff_owns "$_rb_f" "$cwd" "$sname"; then reboot="$_rb_f"; break; fi
  done <<EOF
$_rb_headed
EOF

  # Only a file with NO identity header is genuinely ambiguous. One that HAS a header and
  # still fails handoff_owns is proven to belong to another session — listing that as "may
  # be yours" would be a lie, and it is the common case here (every reboot from another
  # repo). So the pointer list is the complement: candidates minus the header-bearing ones,
  # plus the ambiguous home-folder files demoted above.
  if [ -z "$reboot" ] && [ -n "$_rb_cands" ]; then
    # The bug (found 2026-08-19, silent since this block was written): the trailing
    # `|| printf '%s\n' "$_rb_cands"` treated grep's exit 1 as failure. Exit 1 from
    # `grep -v` means "no lines selected", which here is the CORRECT and common outcome:
    # every candidate carried a header, so the complement is legitimately empty. The
    # fallback then printed the entire candidate list. Net effect, every header-bearing
    # reboot from the last week was offered as "may be this session's", including ones
    # whose own header proves they belong to a different repo. That is the precise lie
    # the comment above says must not happen.
    #
    # On a real failure the list is now empty. Showing nothing beats showing another
    # session's plan as if it might be yours. (`-f` rather than `-e` is only robustness:
    # a multi-line `-e` does split into patterns here, but a filename containing a newline
    # would not survive it.)
    _rb_maybe=$(printf '%s\n' "$_rb_cands" \
                | grep -vxF -f <(printf '%s\n' "$_rb_headed") 2>/dev/null) || _rb_maybe=""
    # Blank-line hygiene. Both halves are routinely empty, and a bare newline is still a
    # non-empty string, so the old concatenation always produced one. That made the
    # pointer file non-empty, which is exactly the test the emit block uses — so the
    # "MAY be this session's" banner printed with nothing listed under it.
    _rb_maybe=$(printf '%s\n%s\n' "$_rb_maybe" "$_rb_demoted" | grep -v '^[[:space:]]*$' || true)
  fi
fi

# Point at headerless reboots only when nothing was provably ours. If an owned reboot was
# found, these are merely files newer than it — and once it has been consumed, surfacing
# them would turn a spent handoff into a recurring "you have unread reboots" nag.
if [ -z "$reboot" ] && [ -n "$_rb_maybe" ] && [ -n "$UNPROVEN_FILE" ]; then
  printf '%s' "$_rb_maybe" >> "$UNPROVEN_FILE" 2>/dev/null || true
fi

# Consume-once. Without it a single /reboot replays into every later /clear for a week,
# turning a one-shot handoff into a permanent context tax. Keyed on path AND mtime, so
# running /reboot again (new filename, new timestamp) always yields a fresh, unconsumed
# marker. If the newest owned reboot is already spent, inject nothing rather than falling
# back to an older one — that would resurrect handoffs the user has already moved past.
#
# Only a REAL session may spend a handoff. Every probe, dry run and test that invokes this hook
# by hand would otherwise silently burn the user's pending reboot — which happened during
# development, and the loss is invisible until the next `/clear` comes up empty. Claude Code
# always supplies session_id; ad-hoc invocations generally do not, so its absence means "look,
# but do not consume". (_rb_sid was resolved next to the claim-ticket lookup, which follows
# the same rule.)
if [ -n "$reboot" ] && [ -n "$_rb_sid" ]; then
  mkdir -p "$REBOOT_STATE_DIR" 2>/dev/null || true
  # The leaf directory is always appended above, so this can only prune files this hook
  # created — never a shared directory someone points OMC_REBOOT_STATE_DIR at.
  find "$REBOOT_STATE_DIR" -maxdepth 1 -type f -mtime +30 -delete 2>/dev/null || true
  _rb_marker="$REBOOT_STATE_DIR/$(handoff_hash "$reboot$(date -r "$reboot" +%s 2>/dev/null || echo 0)")"
  [ -f "$_rb_marker" ] && reboot=""
fi

emitted=0
# The reboot goes FIRST: it is the deliberate reprompt, so it should frame everything after
# it. The auto handoff still follows, because it is the only thing here carrying live git
# state (branch, dirty count) as of the last turn — the reboot's copy is already stale.
if [ -n "$reboot" ]; then
  echo "=== Reboot handoff — resume from this ==="
  head -n "$REBOOT_MAX_LINES" "$reboot" 2>/dev/null || true
  _rb_lines=$(wc -l < "$reboot" 2>/dev/null | tr -d ' ')
  case "$_rb_lines" in ''|*[!0-9]*) _rb_lines=0 ;; esac
  if [ "$_rb_lines" -gt "$REBOOT_MAX_LINES" ]; then
    echo
    echo "_(truncated at $REBOOT_MAX_LINES of $_rb_lines lines — full file: $reboot)_"
  fi
  # Mark spent only now, after it has actually been emitted. Marking at selection time would
  # burn the handoff on a session that never received it.
  [ -n "$_rb_marker" ] && { : > "$_rb_marker" 2>/dev/null || true; }
  emitted=1

  # Rename the session after the task it is resuming. /reboot already chose the slug and put
  # it in the filename (reboot-<YYYY-MM-DD-HHMM>-<slug>.md), so reuse it rather than inventing
  # a second naming scheme. Older files in that directory start with a bare date instead, and
  # a few carry no slug at all — strip the date forms, then require a letter to survive, so a
  # slugless name yields no title rather than titling the session "2026-08-05".
  SESSION_TITLE=$(basename "$reboot" .md \
    | sed 's/^reboot-//; s/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//; s/^[0-9]\{4\}-//')
  case "$SESSION_TITLE" in *[a-zA-Z]*) ;; *) SESSION_TITLE="" ;; esac

  # Belt and braces on the rename. `sessionTitle` is a real SessionStart field (its schema and
  # its apply site are both in the 2.1.223 binary), but it is undocumented, silent on failure,
  # and a version bump could drop it without a word. So when the live name does not already
  # match the slug, put the exact `/rename` line on screen for the user to paste. If the field
  # did its job the names match and this stays quiet, which is what keeps it from nagging.
  if [ -n "$SESSION_TITLE" ] && [ "$sname" != "$SESSION_TITLE" ]; then
    SYSTEM_MSG="Session not renamed automatically. Paste:  /rename $SESSION_TITLE"
  fi

  # Start the first turn automatically — but only after /clear. A `claude -p` or cron run
  # (the 07:15 PR sweep) sitting in a repo that happens to hold an unconsumed reboot must
  # never be diverted into executing it; those arrive as source=startup and are left alone.
  # Consume-once already caps this at one firing per reboot.
  if [ "$source_kind" = "clear" ] && [ -z "${OMC_REBOOT_NO_AUTOSTART:-}" ]; then
    # Deliberately defers to the handoff instead of restating it — the handoff sits directly
    # above this in context. The second sentence matters: a reboot often records FINISHED
    # work, and a bare "continue" sends the model hunting for something to do.
    INITIAL_MSG="Continue from the reboot handoff above. If it reports the work already finished, say so and stop — do not invent follow-up work."
  fi
fi

# Only surface handoffs that are still fresh (<14 days) to avoid stale noise.
if [ -f "$live" ] && [ -z "$(find "$live" -mtime +14 2>/dev/null)" ]; then
  # Separator only when something preceded it, so output is byte-identical to before when
  # no reboot was injected.
  [ "$emitted" -eq 1 ] && echo
  echo "=== Last session handoff (auto) ==="
  cat "$live" 2>/dev/null || true
  emitted=1
fi
if [ -f "$compact" ] && [ -z "$(find "$compact" -mtime +14 2>/dev/null)" ]; then
  echo
  echo "=== Preserved pre-compaction notes (most recent) ==="
  tail -n 40 "$compact" 2>/dev/null || true
  emitted=1
fi
# Same name, different folder. A pane keeps its name while its work drifts: on 2026-09-24
# the "innovation-team" pane (launched in the home folder) spent a morning on Outlook, so /reboot
# stamped that errand as "innovation-team" and the real Innovation Team handoff, keyed to the assistant-bot
# repo, never surfaced. Pointers only, not injected: the name alone does not prove which
# body of work the user means, so the model is told to ask when the two disagree.
if [ -n "$sname" ] && [ -d "$HANDOFF_DIR" ]; then
  _sn_other=$(find "$HANDOFF_DIR" -maxdepth 1 -type f -name '*.md' ! -name '*.compact.md' -mtime -14 -print0 2>/dev/null \
              | xargs -0 grep -lxF -- "- Session: $sname" 2>/dev/null \
              | grep -vxF -e "$live" -e "$compact" \
              | while IFS= read -r _sn_f; do
                  _sn_p=$(sed -n 's/^- Path: `\(.*\)`$/\1/p' "$_sn_f" | head -1)
                  [ -n "$_sn_p" ] && [ "$_sn_p" != "$cwd" ] && printf '%s\n' "$_sn_f"
                done | xargs ls -t 2>/dev/null | head -3)
  if [ -n "$_sn_other" ]; then
    [ "$emitted" -eq 1 ] && echo
    echo "=== Other work under the name \"$sname\" (not loaded) ==="
    echo "If the handoff above does not match what \"$sname\" means, the real one is probably here."
    echo "Read it, or ask which one before acting:"
    printf '%s\n' "$_sn_other" | while IFS= read -r _sn_f; do
      echo "  $_sn_f  ($(date -r "$_sn_f" '+%Y-%m-%d %H:%M' 2>/dev/null))"
    done
    emitted=1
  fi
fi
if [ -n "$UNPROVEN_FILE" ] && [ -s "$UNPROVEN_FILE" ]; then
  echo
  echo "=== Handoffs that MAY be this session's — not loaded ==="
  echo "Nothing in these files proves they belong to this session — either they predate the"
  echo "identity header, or they sit under a key several sessions shared. They are listed"
  echo "rather than injected, because acting on a sibling session's state is worse than"
  echo "having none. Read one only if the path and dates look like your work:"
  sort -u "$UNPROVEN_FILE" 2>/dev/null | head -6 | while IFS= read -r _up; do
    [ -n "$_up" ] || continue
    echo "  $_up  ($(date -r "$_up" '+%Y-%m-%d %H:%M' 2>/dev/null || echo 'unknown date'))"
  done
  echo
  emitted=1
fi
if [ -f "$notes" ]; then
  echo
  echo "=== SESSION_NOTES.md (curated /handoff) ==="
  head -n 60 "$notes" 2>/dev/null || true
  emitted=1
fi

[ "$emitted" -eq 1 ] && { echo; echo "_Resume from the above. Verify branch/dirty state before acting; don't trust it blindly._"; }
exit 0
