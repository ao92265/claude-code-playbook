#!/usr/bin/env bash
# reboot-stamp.sh — PostToolUse(Edit|Write) hook: guarantee the identity block on every
# file written to ~/.claude/reboots/, and drop a same-terminal claim ticket for it.
#
# Why: sessionstart-handoff.sh auto-injects a reboot ONLY when it can prove the file
# belongs to the session being started. Proof comes two ways:
#   1. The identity block ("- Path:" / "- Branch:" / "- Session:") parsed by
#      handoff_owns. The /reboot skill instructs the model to stamp it "every time, no
#      exceptions" — and the model still skips it (reboot-2026-08-11-act-v2-v0-slice2.md
#      shipped headerless). ALWAYS-rules live in hooks, not prose, so this hook stamps
#      mechanically what the skill can only request.
#   2. (since 2026-08-14) A claim ticket keyed by the claude process pid. The process
#      survives /clear, so the pid identifies "the same terminal" with no name at all —
#      which is exactly the case the identity block cannot cover: an unnamed session
#      outside a repo. Before the ticket, those reboots were claimable by EVERY unnamed
#      home session, and with ~10 live sessions a sibling would consume the one-shot
#      reboot between /reboot and /clear, leaving the /clear empty.
#
# The session name is resolved via hooks/lib/session-ident.sh (stdin > env > native
# registry ~/.claude/sessions/<pid>.json) — hook stdin itself never carries a name, so
# without the registry a `claude -n` / /rename name was invisible here. When no explicit
# name exists, the slug in the reboot filename (reboot-<date>-<slug>.md) is stamped
# instead: /reboot chose it deliberately, sessionstart titles the cleared session with
# it, and `claude -n <slug>` in another terminal then provably owns the file.
#
# Never blocks: every path out of here is exit 0. A reboot without a stamp is degraded,
# not fatal, and a Write must never fail because this hook did.
set -uo pipefail

input=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0

fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[ -n "$fp" ] || exit 0

REBOOT_DIR="${OMC_REBOOT_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/reboots}"
case "$fp" in
  "$REBOOT_DIR"/*.md) : ;;
  *) exit 0 ;;
esac
[ -f "$fp" ] || exit 0

# shellcheck source=lib/session-ident.sh
. "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/lib/session-ident.sh"

# Claim ticket — before any header logic, because it must exist even when the model
# already stamped the file itself. One file per terminal, newest reboot wins (a re-run
# /reboot should supersede the previous one for this terminal). The sweep keeps the dir
# bounded; 7 days matches sessionstart's reboot freshness window.
_rs_pid=$(session_ident_pid)
if [ -n "$_rs_pid" ]; then
  PENDING_DIR="${OMC_REBOOT_STATE_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state}/reboot-pending"
  mkdir -p "$PENDING_DIR" 2>/dev/null || true
  find "$PENDING_DIR" -maxdepth 1 -type f -mtime +7 -delete 2>/dev/null || true
  printf '%s\n' "$fp" > "$PENDING_DIR/$_rs_pid" 2>/dev/null || true
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -z "$cwd" ] && cwd="$PWD"

# Session line preference: stdin > env > filename slug > registry. The slug outranks the
# registry deliberately — the stamped name must match what the session will be CALLED
# when it next tries to claim this file, and sessionstart titles the cleared session
# from the filename slug (the skill's different-terminal paste line uses `claude -n
# <slug>` too). The registry holds the PRE-clear name, which the pipeline is about to
# replace; it is only trusted when the filename carries no slug at all. The skill keeps
# the two aligned from the other side: an already-named session reuses its live name AS
# the slug. Strip the reboot- prefix and date forms the same way sessionstart derives
# the title, and require a letter so a slugless file yields no name rather than "1030".
sname=$(printf '%s' "$input" | jq -r '.session_name // empty' 2>/dev/null || true)
[ -z "$sname" ] && sname="${HANDOFF_SESSION_NAME:-}"
if [ -z "$sname" ]; then
  _rs_slug=$(basename "$fp" .md \
    | sed 's/^reboot-//; s/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//; s/^[0-9]\{4\}-//')
  case "$_rs_slug" in *[a-zA-Z]*) sname="$_rs_slug" ;; *) sname="" ;; esac
fi
[ -z "$sname" ] && sname=$(session_ident_name)

if grep -q '^- Path: `' "$fp" 2>/dev/null; then
  # Already stamped. One repair only: a headered file MISSING its Session line (the
  # model ran reboot-identity.sh without the name/slug). Without the line, a non-repo
  # reboot is claimable by any unnamed sibling — the steal this hook exists to prevent.
  # A file that already HAS a Session line passes through untouched, whatever the name:
  # rewriting it would re-address someone's reboot.
  grep -q '^- Session: ' "$fp" 2>/dev/null && exit 0
  [ -n "$sname" ] || exit 0
  tmp=$(mktemp "${TMPDIR:-/tmp}/reboot-stamp.XXXXXX" 2>/dev/null) || exit 0
  # After the Branch line when present, else after the Path line — matching the order
  # reboot-identity.sh emits. handoff_owns greps each line independently either way.
  anchor=$(grep -n -m1 '^- Branch: `' "$fp" 2>/dev/null | cut -d: -f1)
  [ -z "$anchor" ] && anchor=$(grep -n -m1 '^- Path: `' "$fp" 2>/dev/null | cut -d: -f1)
  { head -n "$anchor" "$fp"; printf -- '- Session: %s\n' "$sname"; tail -n +"$((anchor+1))" "$fp"; } > "$tmp" 2>/dev/null
  if [ -s "$tmp" ]; then
    mv -f -- "$tmp" "$fp" 2>/dev/null || rm -f -- "$tmp" 2>/dev/null || true
  else
    rm -f -- "$tmp" 2>/dev/null || true
  fi
  exit 0
fi

block=$("${CLAUDE_CONFIG_DIR:-$HOME/.claude}/scripts/reboot-identity.sh" "$cwd" "$sname" 2>/dev/null || true)
[ -n "$block" ] || exit 0

tmp=$(mktemp "${TMPDIR:-/tmp}/reboot-stamp.XXXXXX" 2>/dev/null) || exit 0

# Insert directly after the first H1 so the file matches what /reboot would have written by
# hand; a file with no H1 gets the block at the very top. Ownership parsing does not care
# where the lines sit, but keeping one canonical shape keeps the files greppable.
h1=$(grep -n -m1 '^# ' "$fp" 2>/dev/null | cut -d: -f1)
if [ -n "$h1" ]; then
  { head -n "$h1" "$fp"; printf '%s\n\n' "$block"; tail -n +"$((h1+1))" "$fp"; } > "$tmp" 2>/dev/null
else
  { printf '%s\n\n' "$block"; cat "$fp"; } > "$tmp" 2>/dev/null
fi

if [ -s "$tmp" ]; then
  mv -f -- "$tmp" "$fp" 2>/dev/null || rm -f -- "$tmp" 2>/dev/null || true
else
  rm -f -- "$tmp" 2>/dev/null || true
fi
exit 0
