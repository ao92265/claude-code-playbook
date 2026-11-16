#!/bin/bash
# pre-commit-guard.sh: blocks git commit when staged JS/TS has console.log or debugger.
source "$(dirname "$0")/lib.sh"
H=pre-commit-guard.sh
R="$TD/repo"; mkdir -p "$R"; cd "$R" || exit 1
git init -q . && git config user.email t@t && git config user.name t
echo base > a.txt && git add a.txt && git commit -qm base

echo 'console.log("x")' > a.ts; git add a.ts
run $H "$(bash_payload 'git commit -m x')"; expect "console.log in staged ts blocked" 2
run $H "$(bash_payload 'git status')";      expect "non-commit command ok" 0
git reset -q a.ts; rm a.ts

echo 'debugger;' > b.js; git add b.js
run $H "$(bash_payload 'git commit -m x')"; expect "debugger in staged js blocked" 2
git reset -q b.js; rm b.js

echo 'console.log("x")' > notes.md; git add notes.md
run $H "$(bash_payload 'git commit -m x')"; expect "console.log in md ok" 0
git reset -q notes.md; rm notes.md

echo 'const a = 1' > c.ts; git add c.ts
run $H "$(bash_payload 'git commit -m x')"; expect "clean ts ok" 0
finish
