# shellcheck shell=bash
# session-ident.sh — resolve the live session's identity from Claude Code's own
# registry: ~/.claude/sessions/<pid>.json (pid, sessionId, cwd, name, nameSource),
# written and pruned by Claude Code itself (same source sessions-board.sh and
# checkpoint-sessions.sh read).
#
# Why this exists: hook stdin carries NO session name field on any event (hooks
# reference, checked against v2.1.223), and HANDOFF_SESSION_NAME is only set by
# restore-sessions launches. So before this lib, a session named with `claude -n`
# or /rename was invisible to every handoff hook — it keyed and stamped as unnamed,
# sharing one home-dir slot with every other unnamed session. The registry is the
# only always-on source of the name, and a hook can find its own entry by walking
# parent pids (the hook process is a child of the claude process).
#
# Name policy: only EXPLICIT names count. nameSource "derived" marks Claude Code's
# auto-generated labels (you-a0, claude-30); those are cosmetic, may be
# re-derived at any time, and must never be used for addressing a handoff — a stamp
# that stops matching after a re-derive silently orphans the file (handoff_owns
# rejects on mismatch and header-bearing rejects are not even listed).
#
# Every function degrades to empty output, never non-zero exit chains that could
# trip a caller's `set -e`. A missing registry means "unnamed", not an error.

# Env-overridable so tests can point at a fixture registry without redirecting the whole
# config dir (which would also redirect the hooks' own lib sourcing).
SESSION_REGISTRY_DIR="${SESSION_REGISTRY_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions}"

# session_ident_pid — print the nearest ancestor pid (starting at $$, max 7 checks)
# that owns a registry file; print nothing if none found. $$ itself is included so
# tests can register their own pid; in production the shell running a hook never
# has an entry, so the walk lands on the claude process (verified live: 2 hops).
session_ident_pid() {
  _si_p=$$
  _si_i=0
  while [ -n "$_si_p" ] && [ "$_si_p" -gt 1 ] 2>/dev/null && [ "$_si_i" -le 6 ]; do
    if [ -f "$SESSION_REGISTRY_DIR/$_si_p.json" ]; then
      printf '%s' "$_si_p"
      return 0
    fi
    _si_p=$(ps -o ppid= -p "$_si_p" 2>/dev/null | tr -d ' ')
    _si_i=$((_si_i + 1))
  done
  return 0
}

# session_ident_name [pid] — the session's explicit name, or nothing. Derived
# names are filtered here (see policy above), so callers can treat any non-empty
# result as deliberately chosen and safe to address handoffs with.
session_ident_name() {
  command -v jq >/dev/null 2>&1 || return 0
  _si_np=${1:-}
  [ -z "$_si_np" ] && _si_np=$(session_ident_pid)
  [ -n "$_si_np" ] || return 0
  _si_nf="$SESSION_REGISTRY_DIR/$_si_np.json"
  [ -f "$_si_nf" ] || return 0
  jq -r 'if (.nameSource // "") == "derived" then "" else (.name // "") end' "$_si_nf" 2>/dev/null || true
}

# session_ident_transcript_title <transcript_path> — the last /rename in THIS session,
# or nothing. A rename persists as a {"type":"custom-title","customTitle":...} line in
# the session's own transcript JSONL (verified in local transcripts and in the binary;
# there is no index file carrying it). Last line wins — renames append. One grep over
# the file, not a tail window: Claude Code's own tail-window scan is exactly the bug in
# anthropics/claude-code#47197, where a rename far from the end stops being seen.
session_ident_transcript_title() {
  [ -n "${1:-}" ] && [ -f "${1:-}" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  grep -a '"type":"custom-title"' "$1" 2>/dev/null | tail -1 \
    | jq -r '.customTitle // empty' 2>/dev/null || true
}

# session_ident_resolve <hook_stdin_json> — the one resolution order every handoff
# hook uses: stdin field (future-proofing: doesn't exist today, wins if it ever
# ships) > HANDOFF_SESSION_NAME env (restore-sessions / checkpoint launches) >
# transcript custom-title (a mid-session /rename — newer than any launch name, and
# not guaranteed to reach the registry) > registry. Prints the name or nothing.
session_ident_resolve() {
  _si_rn=""
  _si_rj="${1:-}"
  if command -v jq >/dev/null 2>&1; then
    _si_rn=$(printf '%s' "$_si_rj" | jq -r '.session_name // empty' 2>/dev/null || true)
  fi
  [ -z "$_si_rn" ] && _si_rn="${HANDOFF_SESSION_NAME:-}"
  if [ -z "$_si_rn" ] && command -v jq >/dev/null 2>&1; then
    _si_rt=$(printf '%s' "$_si_rj" | jq -r '.transcript_path // empty' 2>/dev/null || true)
    _si_rn=$(session_ident_transcript_title "$_si_rt")
  fi
  [ -z "$_si_rn" ] && _si_rn=$(session_ident_name)
  printf '%s' "$_si_rn"
}
