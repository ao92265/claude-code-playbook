#!/usr/bin/env bash
# reboot-identity.sh — print the identity block that /reboot embeds at the top of every
# file it writes to ~/.claude/reboots/.
#
# Why this exists: sessionstart-handoff.sh auto-injects a reboot handoff ONLY when it can
# prove the file belongs to the session being started (handoff_owns, hooks/lib/handoff-key.sh).
# Proof comes from these lines and nothing else — never the filename, never the date. With
# 10 concurrent sessions, injecting a sibling's reprompt is worse than injecting none: it
# reads as your own plan and gets executed. A reboot without this block is listed as
# "may be yours" and left unloaded, which is exactly the manual /resume step we removed.
#
# The format is byte-identical to what stop-handoff.sh writes, because handoff_owns parses
# both with the same sed expressions:
#     - Path: `<abs cwd>`
#     - Session: <name>       (named sessions only)
#     - Branch: `<branch>`    (inside a repo only)
#
# Usage: reboot-identity.sh [cwd] [session-name]
#   cwd           defaults to $PWD
#   session-name  since 2026-08-14 the /reboot skill ALWAYS passes its filename slug here
#                 (reusing the session's live registry name when one exists). Outside a
#                 repo the name is the ONLY ownership signal (see the note at the bottom);
#                 inside a repo it is what separates concurrent named sessions sharing one
#                 repo+branch — since 2026-08-12 handoff_owns rejects a file whose recorded
#                 Session and the current session name are both non-empty and differ.
#                 Same-terminal /clear does not depend on any of this: reboot-stamp.sh
#                 also writes a pid-keyed claim ticket that sessionstart redeems directly.
set -uo pipefail

cwd=${1:-$PWD}
cwd=$(cd "$cwd" 2>/dev/null && pwd) || cwd=${1:-$PWD}
sname=${2:-}

printf -- '- Path: `%s`\n' "$cwd"

top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$top" ]; then
  # Repo session: path + branch prove the worktree deterministically — nothing is guessed.
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
  # Detached HEAD has no branch name. handoff_owns compares the recorded branch against
  # `git branch --show-current`, which is also empty there, so omitting the line matches.
  [ -n "$branch" ] && printf -- '- Branch: `%s`\n' "$branch"
  # The Session line is what separates concurrent NAMED sessions sharing one repo+branch.
  # Omitted for unnamed sessions: an empty side always passes the ownership comparison, so
  # such files stay claimable by any session in this worktree (same as every pre-2026-08-12
  # file, which never carried the line inside a repo).
  [ -n "$sname" ] && printf -- '- Session: %s\n' "$sname"
  exit 0
fi

# Outside a repo, ownership needs the session NAME — and this process cannot discover it.
# It is not exported to the environment (checked: only CLAUDE_CODE_* and the bridge id are),
# so the caller must pass it.
#
# The first version of this script tried to recover the name from the newest handoff in
# handoffs/ recording this cwd. That is unsound and was caught doing exactly the damage it
# was meant to prevent: run from $HOME in an UNNAMED session, it returned
# `- Session: ai-testing-frameworks-overview` — a different, named session that merely
# shared the folder. Stamping that name would have addressed the reboot to someone else's
# session. Path alone cannot separate concurrent sessions in one directory; that ambiguity
# is the entire reason handoff keys were hashed in the first place. So: never infer.
#
# With no name, only the Path line is emitted. handoff_owns compares the absent value
# against the empty session name, so the reboot resolves for an UNNAMED session in this
# folder — sharing one slot with every other unnamed session here, which is the collision
# the startup nudge already warns about. Naming the session (`claude -n <name>`, or
# `/rename <name>`) and passing that name is what makes it individually restorable.
[ -n "$sname" ] && printf -- '- Session: %s\n' "$sname"

exit 0
