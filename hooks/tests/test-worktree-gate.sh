#!/bin/bash
# worktree-gate.sh: one tracked file per session may be edited in a shared main checkout; a second blocks (2).
source "$(dirname "$0")/lib.sh"
H=worktree-gate.sh
export WORKTREE_GATE_STATE="$TD/state"
# The hook never gates files under /tmp, which is where mktemp puts $TD on Linux CI.
# /var/tmp is not skipped on Linux or macOS, so the repo lives there.
W=$(mktemp -d /var/tmp/wtgate.XXXXXX) || exit 1
trap 'rm -rf "$TD" "$W"' EXIT
R="$W/repo"; mkdir -p "$R/sub"; cd "$R" || exit 1
git init -q . && git config user.email t@example.com && git config user.name t
echo ignored.log > .gitignore; echo a > a.ts; echo b > b.ts; git add -A; git commit -qm init
ed() { run $H "$(jq -nc --arg f "$1" --arg s "$2" '{session_id:$s,tool_input:{file_path:$f}}')" "${@:3}"; }

ed "$R/a.ts" s1;                 expect "first file in main checkout allowed" 0
ed "$R/a.ts" s1;                 expect "same file again allowed" 0
ed "$R/b.ts" s1;                 expect "second distinct file blocked" 2
expect_has "message names EnterWorktree" "$ERR" "EnterWorktree"
ed "$R/sub/../a.ts" s1;          expect "dotdot spelling of first file counts once" 0
ed "$R/b.ts" s2;                 expect "other session has its own free edit" 0
ed "$R/b.ts" s1 CLAUDE_SKIP_HOOKS=worktree-gate; expect "skip env honoured" 0
ed "$R/b.ts" s1 CLAUDE_CODE_ENTRYPOINT=sdk-cli;  expect "headless entrypoint never gated" 0
ed "$R/ignored.log" s1;          expect "gitignored file not gated" 0
ed "$R/.omc/plan.md" s1;         expect ".omc state not gated" 0
ed "$R/b.ts" "";                 expect "no session id not gated" 0
ed "$TD/outside/x.ts" s1;        expect "outside git not gated" 0
run $H '{"session_id":"s1","tool_input":{}}'; expect "no file_path ok" 0

git worktree add -q "$W/wt" -b side 2>/dev/null
ed "$W/wt/a.ts" s3; ed "$W/wt/b.ts" s3; expect "linked worktree never gated" 0
finish
