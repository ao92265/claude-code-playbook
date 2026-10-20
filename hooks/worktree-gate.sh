#!/bin/bash
# worktree-gate.sh: PreToolUse(Edit|Write|MultiEdit|NotebookEdit) gate.
#
# Why: Isolation discipline scored 10/100 on myinsights (6 Oct 2026). Only 67 of
# 1,100 interactive sessions ran in a worktree. branch-guard already blocks when
# two live sessions share a branch. This closes the remaining gap: one session
# building across several files in a repo's shared main checkout.
#
# Rule: per session, ONE tracked file may be edited in a repo's main checkout (a
# one-line fix stays cheap). A second distinct file there is blocked, and the
# message tells the session to call EnterWorktree and carry on. Edits inside a
# linked worktree, outside git, to gitignored files, and in headless SDK runs
# (pipelines, not a person choosing) and scratch or temp folders are never gated.
#
# Disable: CLAUDE_SKIP_HOOKS=worktree-gate, set when launching claude.
SKIP_HOOKS="${CLAUDE_SKIP_HOOKS:-}${CLAUDE_SKIP_HOOKS:+,}${OMC_SKIP_HOOKS:-}"
case ",${SKIP_HOOKS}," in *,worktree-gate,*) exit 0 ;; esac
case "${CLAUDE_CODE_ENTRYPOINT:-cli}" in cli|claude-vscode|claude-desktop|claude-desktop-3p) ;; *) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null || true)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$FILE" ] || [ -z "$SID" ] && exit 0          # no session id: nothing safe to count against
case "$FILE" in /*) ;; *) FILE="$PWD/$FILE" ;; esac
# Scratch and temp areas are throwaway and already count as isolated.
# Agent state in .omc is not the work itself, so it never uses up the free edit.
case "$FILE" in /tmp/*|/private/tmp/*|"$HOME"/Repos/.agent-worktrees/*|*/.omc/*) exit 0 ;; esac

# Nearest existing directory, since Write may create new folders.
DIR=$(dirname "$FILE")
while [ ! -d "$DIR" ] && [ "$DIR" != "/" ]; do DIR=$(dirname "$DIR"); done
TOP=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
GD=$(cd "$DIR" && cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P) || exit 0
CD=$(cd "$DIR" && cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P) || exit 0
[ "$GD" != "$CD" ] && exit 0                       # linked worktree: isolated already
git -C "$DIR" check-ignore -q "$FILE" 2>/dev/null && exit 0

STATE="${WORKTREE_GATE_STATE:-$HOME/.claude/state}"
mkdir -p "$STATE" 2>/dev/null || exit 0
KEY=$(printf '%s' "$TOP" | shasum | cut -c1-12)
MARK="$STATE/worktreegate-${SID}-${KEY}"
# Canonical path relative to the repo, so a symlink or sub/.. spelling counts once.
TOPR=$(cd "$TOP" && pwd -P); DIRR=$(cd "$DIR" && pwd -P)
REAL="${DIRR}${FILE#"$DIR"}"; REAL="${REAL#"$TOPR"/}"

if [ ! -s "$MARK" ]; then
  printf '%s\n' "$REAL" > "$MARK"
  find "$STATE" -maxdepth 1 -name 'worktreegate-*' -mtime +3 -delete 2>/dev/null
  exit 0
fi
[ "$(head -1 "$MARK")" = "$REAL" ] && exit 0

echo "BLOCKED by worktree-gate: this session already edited $(head -1 "$MARK") in the shared main checkout of $TOP, and $FILE would be a second file. Multi-file work goes in an isolated worktree. Call the EnterWorktree tool now (load it with ToolSearch if it is deferred), then redo this edit at the same relative path inside the worktree, and re-apply the earlier edit there too. Leave the main checkout copy alone and mention it in your reply. Do not ask the user first; this is the standing rule." >&2
exit 2
