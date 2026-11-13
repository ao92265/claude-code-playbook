#!/bin/bash
# env-guard.sh: blocks git add/commit when .env or secret-looking lines are staged.
source "$(dirname "$0")/lib.sh"
H=env-guard.sh
R="$TD/repo"; mkdir -p "$R"; cd "$R" || exit 1
git init -q . && git config user.email t@t && git config user.name t
echo base > a.txt && git add a.txt && git commit -qm base

run $H "$(bash_payload 'ls')";            expect "non-git command ok" 0
run $H "$(bash_payload 'git commit -m x')"; expect "clean index ok" 0

echo 'X=1' > .env; git add .env
run $H "$(bash_payload 'git commit -m x')"; expect ".env staged blocked (commit)" 2
run $H "$(bash_payload 'git add .')";       expect ".env staged blocked (add)" 2
run $H "$(bash_payload 'ls')";              expect ".env staged, unrelated command ok" 0
git reset -q .env; rm .env

for n in .env.production .env.staging .env.development .env.local; do
  echo 'X=1' > "$n"; git add "$n"
  run $H "$(bash_payload 'git commit -m x')"; expect "$n staged blocked" 2
  git reset -q "$n"; rm "$n"
done
echo 'password = "hunter2hunter2"' > cfg.txt; git add cfg.txt
run $H "$(bash_payload 'git commit -m x')"; expect "secret line staged blocked" 2
expect_has "message names secrets" "$ERR" "Potential secrets"
git reset -q cfg.txt; rm cfg.txt

echo 'DATABASE_URL=x' > ok.txt; git add ok.txt
run $H "$(bash_payload 'git commit -m x')"; expect "DATABASE_URL staged blocked" 2
finish
