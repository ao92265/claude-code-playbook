#!/bin/bash
# worktree-gate.sh: one file may be edited in a repo's main checkout per session;
# a second distinct file there is blocked until the session moves into a worktree.
HOOK="$HOME/.claude/hooks/worktree-gate.sh"
FAIL=0
T=$(mktemp -d); export HOME_STATE="$T/state"
R="$T/repo"; git init -q "$R" && git -C "$R" commit -q --allow-empty -m init
git -C "$R" worktree add -q "$T/wt" -b wt-branch 2>/dev/null
run() { # want, label, session ("-" = none), file, [entrypoint]
  if [ "$3" = "-" ]; then J=$(jq -n --arg f "$4" '{tool_name:"Edit", tool_input:{file_path:$f}}')
  else J=$(jq -n --arg s "$3" --arg f "$4" '{session_id:$s, tool_name:"Edit", tool_input:{file_path:$f}}'); fi
  printf '%s' "$J" | env -u CLAUDE_SKIP_HOOKS WORKTREE_GATE_STATE="$HOME_STATE" CLAUDE_CODE_ENTRYPOINT="${5:-cli}" "$HOOK" >/dev/null 2>"$T/err"; got=$?
  [ "$got" -eq "$1" ] && echo "OK   $2" || { echo "FAIL $2 (want $1 got $got)"; FAIL=$((FAIL+1)); }; }
run 0 "first file in main checkout is allowed" s1 "$R/a.txt"
run 0 "same file again is allowed" s1 "$R/a.txt"
run 2 "second distinct file in main checkout is blocked" s1 "$R/b.txt"
grep -q EnterWorktree "$T/err" && echo "OK   block message names EnterWorktree" || { echo "FAIL block message names EnterWorktree"; FAIL=$((FAIL+1)); }
run 0 "a new file in a subfolder counts per repo, other session unaffected" s2 "$R/sub/new.txt"
run 0 "edits inside a linked worktree are allowed" s1 "$T/wt/a.txt"
run 0 "more edits inside the worktree are allowed" s1 "$T/wt/c.txt"
run 0 "paths outside any git repo are allowed" s1 "$T/plain/x.txt"
run 0 "first file again after a block is still allowed" s1 "$R/a.txt"
run 0 "headless SDK runs are not gated" s3 "$R/b.txt" sdk-ts
run 0 "headless SDK runs are not gated (second file)" s3 "$R/c.txt" sdk-ts
run 0 "scratch and temp folders are not gated" s1 "/private/tmp/x/scratchpad/q.txt"
run 0 "agent state in .omc does not use up the free edit" s4 "$R/.omc/plans/x.md"
run 0 "first real file after .omc edits is allowed" s4 "$R/a.txt"
ln -s "$R" "$T/link"
run 0 "same file through a symlink counts once" s4 "$T/link/a.txt"
mkdir -p "$R/sub"
run 0 "same file through sub/.. counts once" s4 "$R/sub/../a.txt"
run 0 "missing session id is not gated (1)" - "$R/a.txt"
run 0 "missing session id is not gated (2)" - "$R/b.txt"
run 0 "desktop on Bedrock or Vertex: first file" s5 "$R/a.txt" claude-desktop-3p
run 2 "desktop on Bedrock or Vertex is gated (second file)" s5 "$R/b.txt" claude-desktop-3p
mkdir -p "$R/scratchpad"
run 0 "first file for s6" s6 "$R/a.txt"
run 2 "a repo folder named scratchpad is not exempt" s6 "$R/scratchpad/n.txt"
rm -rf "$T"
echo "failures: $FAIL"; exit $FAIL
