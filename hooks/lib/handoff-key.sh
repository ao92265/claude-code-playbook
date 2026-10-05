# shellcheck shell=bash
# Shared handoff key computation. Sourced by stop-handoff.sh, sessionstart-handoff.sh
# and precompact-handoff.sh — all three MUST agree or a session writes to one file and
# reads from another, silently.
#
# Why this exists: the key used to be the working directory alone. 79 of 204 sessions in
# the Aug 2026 corpus ran from $HOME, so every one of them wrote to the same handoff file
# and only the newest survived — which is why most sessions were spent re-establishing
# context instead of doing work.
#
# Key = <readable prefix>-<8 hex chars of a hash over the canonical identity>.
#
# The hash is what actually guarantees uniqueness; the prefix is only so a human can tell
# the files apart in `ls`. Both are needed — a readable-only key collides two ways, and
# both were live bugs in the first version of this file (caught in review, 2026-08-05):
#
#   1. basename alone is ambiguous. ~/Repos/acmeco/Scheduler and ~/Repos/other/Scheduler
#      on the same branch both produced "Scheduler--main".
#   2. slugifying maps "/" to "-", so branch "fix/foo" and branch "fix-foo" in the same
#      repo both produced "<repo>--fix-foo". Slash-prefixed branches are the norm here
#      (feat/, fix/, banks/), so this was not hypothetical.
#
# Hashing the raw, unslugified identity with a separator that cannot occur in a path or a
# git ref (0x1f, ASCII unit separator) removes both. git also forbids 0x1f in ref names.
#
# Identity, in priority order:
#   1. inside a git repo, NAMED session   -> repo<US><abs toplevel><US><branch><US><name>
#      (since 2026-08-12: two named sessions in the same repo+branch used to share one
#      key, newest wins — with ~10 concurrent sessions that silently handed one session
#      the other's state. Readers fall back to the nameless form via
#      handoff_repo_shared_key so nothing written before the change is orphaned.)
#   2. inside a git repo, unnamed session -> repo<US><abs toplevel><US><branch>
#      (worktrees resolve to their own toplevel, so two worktrees of one repo differ)
#   3. named session outside a repo       -> name<US><cwd><US><session name>
#   4. none of the above                  -> legacy cwd slug, byte-identical to the
#      pre-2026-08-05 scheme so existing handoffs keep resolving. Still collides between
#      unnamed sessions in the same folder — the startup nudge fires for exactly that case.

# Longest readable prefix kept before the hash suffix. Keeps filenames well under the
# 255-byte limit even with a long repo name and a long branch name.
HANDOFF_PREFIX_MAX=${HANDOFF_PREFIX_MAX:-72}

handoff_slugify() {
  printf '%s' "$1" | sed 's#^/##; s#[/ ]#-#g; s#[^A-Za-z0-9._-]#-#g'
}

# 8 hex chars. shasum on macOS, sha256sum on most Linux, cksum as a last resort so the
# hook degrades to "still works, weaker" rather than "writes an empty key".
handoff_hash() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 2>/dev/null | cut -c1-8
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum 2>/dev/null | cut -c1-8
  else
    printf '%s' "$1" | cksum 2>/dev/null | awk '{printf "%08x", $1}' | cut -c1-8
  fi
}

# Trim the readable part, never the hash.
handoff_trim() {
  printf '%s' "$1" | cut -c1-"$HANDOFF_PREFIX_MAX" | sed 's/-*$//'
}

handoff_legacy_key() {
  handoff_slugify "$1"
}

# The un-hashed key that shipped in 341c058 and was replaced ~12 minutes later in 3069b36.
# Short-lived, but sessions that stopped inside that window wrote their only handoff under
# it. Readers include it as a candidate so those are not orphaned. Safe to delete once
# nothing in handoffs/ predates 2026-08-05 — the 30-day sweep in maintenance.sh gets there.
handoff_intermediate_key() {
  _hi_cwd=$1
  _hi_name=${2:-}
  _hi_top=$(git -C "$_hi_cwd" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$_hi_top" ]; then
    _hi_branch=$(git -C "$_hi_cwd" branch --show-current 2>/dev/null || true)
    [ -z "$_hi_branch" ] && _hi_branch=$(git -C "$_hi_cwd" rev-parse --short HEAD 2>/dev/null || true)
    [ -z "$_hi_branch" ] && _hi_branch="nobranch"
    printf '%s--%s' "$(handoff_slugify "$(basename "$_hi_top")")" "$(handoff_slugify "$_hi_branch")"
    return 0
  fi
  if [ -n "$_hi_name" ]; then
    printf '%s--%s' "$(handoff_slugify "$_hi_cwd")" "$(handoff_slugify "$_hi_name")"
    return 0
  fi
  handoff_legacy_key "$_hi_cwd"
}

# handoff_owns <file> <cwd> [session_name]
# True only when <file> provably belongs to this session.
#
# Required because the two historical key formats are exactly the ambiguous ones the
# hashed key replaced. Offering them as read fallbacks without a check is worse than
# orphaning: two repos named Scheduler both answer to "Scheduler--main", and EVERY named
# session in $HOME answers to the legacy key "Users-you" — so a fallback would hand
# one session another session's state and it would be acted on as if it were its own.
#
# Handoff bodies carry "- Path:", "- Branch:" and (since 2026-08-05) "- Session:".
# Ownership is proven from those, never from the filename.
handoff_owns() {
  _ho_file=$1; _ho_cwd=$2; _ho_name=${3:-}
  [ -f "$_ho_file" ] || return 1

  _ho_recpath=$(sed -n 's/^- Path: `\(.*\)`$/\1/p' "$_ho_file" 2>/dev/null | head -1)
  # No identity header -> ownership is not provable, full stop.
  #
  # There was briefly a "defer to the sibling <key>.md" rule here. It was unsound. The
  # sibling proves who wrote THE SIBLING, and under an ambiguous key that is merely the
  # most recent writer — the whole reason those keys are ambiguous is that many sessions
  # wrote to them, newest wins. Two different unnamed $HOME sessions, or two branches of
  # one repo sharing the legacy cwd key, satisfy the sibling test while having nothing to
  # do with each other. And under an UNambiguous key the inference is never needed, since
  # the key is the proof. It could only ever fire where it was invalid.
  #
  # Headerless files are surfaced as a pointer by sessionstart instead of being injected,
  # so they are neither silently dropped nor silently misattributed.
  [ -n "$_ho_recpath" ] || return 1

  _ho_top=$(git -C "$_ho_cwd" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$_ho_top" ]; then
    # Repo session: the recorded path must sit in the SAME worktree, on the same branch.
    _ho_rectop=$(git -C "$_ho_recpath" rev-parse --show-toplevel 2>/dev/null || true)
    [ "$_ho_rectop" = "$_ho_top" ] || return 1
    _ho_branch=$(git -C "$_ho_cwd" branch --show-current 2>/dev/null || true)
    _ho_recbranch=$(sed -n 's/^- Branch: `\(.*\)`$/\1/p' "$_ho_file" 2>/dev/null | head -1)
    [ "$_ho_recbranch" = "$_ho_branch" ] || return 1
    # Session names separate concurrent sessions in one repo+branch. Reject ONLY when both
    # sides are non-empty and differ: files written before 2026-08-12 carry no Session line
    # inside repos, and an unnamed session has no name to compare — both of those must stay
    # claimable, or every existing handoff would be orphaned by this check.
    _ho_recname=$(sed -n 's/^- Session: \(.*\)$/\1/p' "$_ho_file" 2>/dev/null | head -1)
    if [ -n "$_ho_recname" ] && [ -n "$_ho_name" ] && [ "$_ho_recname" != "$_ho_name" ]; then
      return 1
    fi
    return 0
  fi

  # Non-repo session: same cwd AND same session name. A file with no "- Session:" line
  # belongs to an unnamed session, so only an unnamed session may claim it.
  [ "$_ho_recpath" = "$_ho_cwd" ] || return 1
  _ho_recname=$(sed -n 's/^- Session: \(.*\)$/\1/p' "$_ho_file" 2>/dev/null | head -1)
  [ "$_ho_recname" = "$_ho_name" ] || return 1
  return 0
}

# handoff_newest <dir> <suffix> <key>...
# Echo the path of the newest existing <dir>/<key><suffix>, or nothing. Newest-wins rather
# than first-match: a session's last write may have landed under an older key format, and
# that file is then the freshest thing we have.
handoff_newest() {
  _hn_dir=$1; _hn_suffix=$2; shift 2
  _hn_best=""
  for _hn_k in "$@"; do
    [ -n "$_hn_k" ] || continue
    _hn_f="$_hn_dir/${_hn_k}${_hn_suffix}"
    [ -f "$_hn_f" ] || continue
    if [ -z "$_hn_best" ] || [ "$_hn_f" -nt "$_hn_best" ]; then _hn_best="$_hn_f"; fi
  done
  [ -n "$_hn_best" ] && printf '%s' "$_hn_best"
}

# handoff_repo_shared_key <cwd>
# The nameless repo+branch key — the only repo key format before 2026-08-12, and still the
# write key for UNNAMED repo sessions. Readers offer it as a fallback candidate so a named
# session finds handoffs written before the change (or while it was unnamed); those reads
# go through handoff_owns like every other ambiguous candidate. Echoes nothing outside a
# repo.
handoff_repo_shared_key() {
  _hs_cwd=$1
  _hs_us=$(printf '\037')
  _hs_top=$(git -C "$_hs_cwd" rev-parse --show-toplevel 2>/dev/null || true)
  [ -n "$_hs_top" ] || return 0
  _hs_branch=$(git -C "$_hs_cwd" branch --show-current 2>/dev/null || true)
  # detached HEAD: short sha keeps the key stable within a checkout
  [ -z "$_hs_branch" ] && _hs_branch=$(git -C "$_hs_cwd" rev-parse --short HEAD 2>/dev/null || true)
  [ -z "$_hs_branch" ] && _hs_branch="nobranch"
  _hs_id="repo${_hs_us}${_hs_top}${_hs_us}${_hs_branch}"
  _hs_pretty="$(handoff_slugify "$(basename "$_hs_top")")--$(handoff_slugify "$_hs_branch")"
  printf '%s-%s' "$(handoff_trim "$_hs_pretty")" "$(handoff_hash "$_hs_id")"
}

# handoff_key <cwd> [session_name]
handoff_key() {
  _hk_cwd=$1
  _hk_name=${2:-}
  _hk_us=$(printf '\037')

  _hk_top=$(git -C "$_hk_cwd" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$_hk_top" ]; then
    # Unnamed repo session: byte-identical to the pre-2026-08-12 key.
    if [ -z "$_hk_name" ]; then
      handoff_repo_shared_key "$_hk_cwd"
      return 0
    fi
    _hk_branch=$(git -C "$_hk_cwd" branch --show-current 2>/dev/null || true)
    # detached HEAD: short sha keeps the key stable within a checkout
    [ -z "$_hk_branch" ] && _hk_branch=$(git -C "$_hk_cwd" rev-parse --short HEAD 2>/dev/null || true)
    [ -z "$_hk_branch" ] && _hk_branch="nobranch"
    _hk_id="repo${_hk_us}${_hk_top}${_hk_us}${_hk_branch}${_hk_us}${_hk_name}"
    _hk_pretty="$(handoff_slugify "$(basename "$_hk_top")")--$(handoff_slugify "$_hk_branch")--$(handoff_slugify "$_hk_name")"
    printf '%s-%s' "$(handoff_trim "$_hk_pretty")" "$(handoff_hash "$_hk_id")"
    return 0
  fi

  if [ -n "$_hk_name" ]; then
    _hk_id="name${_hk_us}${_hk_cwd}${_hk_us}${_hk_name}"
    _hk_pretty="$(handoff_slugify "$_hk_cwd")--$(handoff_slugify "$_hk_name")"
    printf '%s-%s' "$(handoff_trim "$_hk_pretty")" "$(handoff_hash "$_hk_id")"
    return 0
  fi

  handoff_legacy_key "$_hk_cwd"
}
