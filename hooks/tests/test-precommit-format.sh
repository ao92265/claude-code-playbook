#!/bin/bash
# precommit-format.sh: a commit command normalizes CRLF to LF on staged text files and re-stages them; never blocks.
source "$(dirname "$0")/lib.sh"
H=precommit-format.sh
W="$TD/w"; mkdir -p "$W"; cd "$W" || exit 1
git init -q -b main .
C=$(bash_payload "git commit -m change")
stage_crlf() { printf 'one\r\ntwo\r\n' > t.txt; git add t.txt; }
crs() { git show :t.txt | LC_ALL=C grep -c $'\r'; }
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }

stage_crlf
run $H "$(bash_payload "git status")";    expect "non-commit ignored" 0
check "non-commit leaves CRLF" '[[ $(crs) == 2 ]]'
run $H "$C" DISABLE_PRECOMMIT_FORMAT=1;   expect "disable env exits 0" 0
check "disable env leaves CRLF" '[[ $(crs) == 2 ]]'
run $H "$(bash_payload "git commit -m '[wip] x'")"; expect "wip marker exits 0" 0
check "wip leaves CRLF" '[[ $(crs) == 2 ]]'
run $H "$C" CLAUDE_SKIP_HOOKS=precommit-format; expect "skip env exits 0" 0
check "skip env leaves CRLF" '[[ $(crs) == 2 ]]'
run $H "$C";                              expect "normalize run never blocks" 0
check "staged CRLF became LF" '[[ $(crs) == 0 ]]'
check "file re-staged, tree clean" '[[ -z "$(git diff --name-only)" ]]'
expect_has "reports the normalization" "$ERR" "normalized line endings"

# binary files are left alone
git reset -q; printf 'a\r\n\000b\r\n' > bin.dat; git add bin.dat
run $H "$C";                              expect "binary run exits 0" 0
check "binary CRLF untouched" '[[ $(git show :bin.dat | LC_ALL=C grep -ac $'"'"'\r'"'"') == 2 ]]'

# per-repo override takes over and the hook does nothing else
git reset -q; stage_crlf
mkdir -p .claude/hooks; printf '#!/bin/bash\ntouch override.ran\n' > .claude/hooks/auto-format.sh; chmod +x .claude/hooks/auto-format.sh
run $H "$C";                              expect "override exits 0" 0
check "repo override ran" '[[ -f override.ran ]]'
check "override owns formatting, CRLF kept" '[[ $(crs) == 2 ]]'
finish
