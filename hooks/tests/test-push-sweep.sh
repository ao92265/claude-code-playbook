#!/bin/bash
# push-sweep.sh: Stop hook warns once per repo+HEAD about unpushed commits; silent when nothing to sweep. Never blocks.
source "$(dirname "$0")/lib.sh"
H=push-sweep.sh
G="git -c user.email=t@example.com -c user.name=t"
R="$TD/remote.git"; git init -q --bare "$R"
W="$TD/work"; mkdir -p "$W"; cd "$W" || exit 1
git init -q -b main .; echo a > a; git add a; $G commit -q -m one
P=$(jq -nc --arg c "$W" '{cwd:$c}')

run $H "$P";                              expect "no remote exits 0" 0
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   no remote is silent"; } || { fail=$((fail+1)); echo "FAIL warned with no remote"; }
git remote add origin "$R"; git push -q -u origin main
run $H "$P"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   fully pushed is silent"; } || { fail=$((fail+1)); echo "FAIL warned when pushed"; }
echo b > b; git add b; $G commit -q -m two
run $H "$P";                              expect "unpushed run exits 0" 0
expect_has "warns with count" "$OUT" "1 unpushed commit(s) on work:main"
expect_has "is a systemMessage" "$(printf '%s' "$OUT" | jq -r '.systemMessage // empty')" "push-sweep"
run $H "$P"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   same HEAD warns only once"; } || { fail=$((fail+1)); echo "FAIL repeated warning"; }
echo c > c; git add c; $G commit -q -m three
run $H "$P"
expect_has "new HEAD warns again with new count" "$OUT" "2 unpushed commit(s)"
git checkout -q --detach; $G commit --allow-empty -q -m detached-work
run $H "$P"
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   detached HEAD is silent"; } || { fail=$((fail+1)); echo "FAIL warned on detached HEAD"; }
run $H '{"cwd":"/nonexistent/dir"}';      expect "missing cwd exits 0" 0
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   missing cwd is silent"; } || { fail=$((fail+1)); echo "FAIL output for missing cwd"; }
finish
