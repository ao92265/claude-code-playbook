#!/bin/bash
# research-only-guard.sh: with the flag present, writes and mutating Bash exit 2.
source "$(dirname "$0")/lib.sh"
H=research-only-guard.sh
W="$TD/w"; mkdir -p "$W"; cd "$W" || exit 1
try() { run $H "$(bash_payload "$2")"; expect "$1" "$3"; }

try "no flag: mutation ok" 'rm x' 0
run $H "$(file_payload Write /p/a.txt hi)"; expect "no flag: Write ok" 0

mkdir -p .claude/state; touch .claude/state/research-only.flag
run $H "$(file_payload Write /p/a.txt hi)"; expect "flag: Write blocked" 2
try "flag: redirect blocked"      'echo hi > out.txt' 2
try "flag: tee blocked"           'echo hi | tee out.txt' 2
try "flag: sed -i blocked"        'sed -i s/a/b/ f' 2
try "flag: python blocked"        'python3 x.py' 2
try "flag: rm blocked"            'rm f' 2
try "flag: git commit blocked"    'git commit -m x' 2
try "flag: npm install blocked"   'npm install' 2
try "flag: make blocked"          'make build' 2
try "flag: gh pr create blocked"  'gh pr create' 2
try "flag: gh api POST blocked"   'gh api x -X POST' 2
try "flag: git add blocked"       'git add .' 2
try "flag: git log ok"            'git log --oneline' 0
try "flag: ls ok"                 'ls -la' 0
try "flag: cat ok"                'cat a.txt' 0
try "flag: grep -i ok"            'grep -i foo a.txt' 0
try "flag: 2>&1 ok"               'ls 2>&1' 0
try "flag: gh pr view ok"         'gh pr view 3' 0
try "flag: quoted text ignored"   'echo "rm -rf x"' 0
finish
