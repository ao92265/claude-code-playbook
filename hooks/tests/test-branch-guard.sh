#!/bin/bash
# branch-guard.sh: first edit per repo reports branch and dirty state; a live peer on the same branch blocks (2),
# on edit and on `git push` to a branch another live session sits on.
source "$(dirname "$0")/lib.sh"
H=branch-guard.sh
R="$TD/repo"; mkdir -p "$R"; git -C "$R" init -q -b main . ; git -C "$R" config user.email t@example.com; git -C "$R" config user.name t
echo a > "$R/a.txt"; git -C "$R" add -A; git -C "$R" commit -qm init
git -C "$R" branch feat
git -C "$R" worktree add -q "$TD/wt" feat
REG="$HOME/.claude/sessions"; mkdir -p "$REG"
peer() { jq -nc --arg n "$1" --arg c "$2" --argjson p "$3" '{pid:$p,sessionId:$n,cwd:$c,name:$n}' > "$REG/$1.json"; }
unpeer() { rm "$REG"/*.json 2>/dev/null; true; }
edit() { run $H "$(jq -nc --arg f "$1" --arg s "$2" '{session_id:$s,tool_input:{file_path:$f}}')" "${@:3}"; }
push() { cd "$1" || return; run $H "$(bash_payload "$2")"; cd "$TD" || return; }
LIVE=$$

edit "$TD/outside/x.ts" s1;                  expect "outside git is silent" 0
expect_lacks "outside git prints nothing" "$OUT" "branch-guard"
echo dirty > "$R/new.txt"
edit "$R/a.txt" s1;                          expect "first edit allowed" 0
expect_has "reports the branch" "$OUT" 'Branch `main`'
expect_has "reports dirty count" "$OUT" "1 uncommitted"
edit "$R/a.txt" s1;                          expect_lacks "second edit in same repo is quiet" "$OUT" "branch-guard"
edit "$R/a.txt" s2;                          expect_has "new session gets its own report" "$OUT" "branch-guard"
edit "$R/a.txt" s4 BRANCH_GUARD_DISABLED=1;  expect_lacks "disable env honoured" "$OUT" "branch-guard"

# peer on the same branch blocks edits
peer other "$R" $LIVE
edit "$R/a.txt" s5;                          expect "live peer on same branch blocks" 2
expect_has "names the peer" "$ERR" "other"
edit "$R/a.txt" s5 CLAUDE_SKIP_HOOKS=branch-guard; expect "skip env overrides the block" 0
edit "$R/a.txt" other;                       expect_lacks "own registry entry is not a peer" "$ERR" "BLOCKED"
peer other "$R" 999999
edit "$R/a.txt" s6;                          expect "dead peer pid ignored" 0
peer other "$TD/wt" $LIVE
edit "$R/a.txt" s7;                          expect "peer on another branch does not block" 0
expect_has "peer elsewhere in repo is named" "$OUT" "Also live in this repo"
unpeer

# push mode
push "$R" 'git push origin main';            expect "push with no peers allowed" 0
push "$R" 'echo "git push origin feat"';     expect "quoted mention is not a push" 0
peer other "$TD/wt" $LIVE
push "$R" 'git push origin feat';            expect "push to a branch a live peer owns blocks" 2
expect_has "push message names the branch" "$ERR" "feat"
push "$R" 'git push origin HEAD:feat';       expect "HEAD:name refspec target is checked" 2
push "$R" 'git push origin main';            expect "push to a different branch allowed" 0
push "$TD/wt" 'git push origin feat';        expect "peer in the same working tree is not a collision" 0
unpeer
finish
