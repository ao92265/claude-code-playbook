#!/bin/bash
# commit-message-check.sh: git commit -m "..." must use a conventional prefix.
source "$(dirname "$0")/lib.sh"
H=commit-message-check.sh
# The hook uses grep -P (PCRE). BSD grep on macOS lacks it; skip there.
if ! echo x | grep -qP 'x' 2>/dev/null; then echo "SKIP grep -P unavailable"; exit 0; fi
try() { run $H "$(bash_payload "$2")"; expect "$1" "$3"; }

try "feat prefix ok"          'git commit -m "feat: add thing"' 0
try "scoped fix ok"           'git commit -m "fix(auth): null check"' 0
try "breaking bang ok"        'git commit -m "feat!: drop api"' 0
try "no prefix blocked"       'git commit -m "add thing"' 2
try "bad type blocked"        'git commit -m "wip: add thing"' 2
try "single quotes blocked"   "git commit -m 'add thing'" 2
try "single quotes ok"        "git commit -m 'docs: add thing'" 0
try "heredoc skipped"         'git commit -F msg.txt' 0
try "non-commit skipped"      'git status' 0
finish
