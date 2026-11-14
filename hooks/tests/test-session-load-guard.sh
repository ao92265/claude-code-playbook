#!/bin/bash
# session-load-guard.sh: SessionStart warns when live sessions exceed the working limit or any is past the 4h cap.
source "$(dirname "$0")/lib.sh"
H=session-load-guard.sh
BOARD="$HOME/.claude/scripts/sessions-board.sh"; mkdir -p "$HOME/.claude/scripts"
board() { printf '#!/bin/bash\ncat <<"B"\n%s\nB\n' "$1" > "$BOARD"; }
chk() { run $H '' "$@"; }

chk;                                      expect "no board exits 0" 0
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   no board is silent"; } || { fail=$((fail+1)); echo "FAIL output without board"; }
board "2 live Claude sessions
row one
row two"
chk;                                      expect "under limit exits 0" 0
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   under limit is silent"; } || { fail=$((fail+1)); echo "FAIL warned under limit"; }
board "5 live Claude sessions
row"
chk
expect_has "over limit warns" "$OUT" "SESSION LOAD: 5 live Claude sessions (working limit 3)"
expect_lacks "no stale list without stale rows" "$OUT" "past the 4h cap"
expect_has "tells model to hold the warning" "$OUT" "HOLD THIS"
board "2 live Claude sessions
row fresh
row old ⚠ idle 5h
⚠ = idle over 4h"
chk
expect_has "stale session warns even under limit" "$OUT" "1 past the 4h cap"
expect_has "stale row listed" "$OUT" "row old"
expect_lacks "legend line not counted as a row" "$OUT" "2 past"
board "9 live Claude sessions"
chk CLAUDE_SKIP_HOOKS=session-load-guard
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   skip env honoured"; } || { fail=$((fail+1)); echo "FAIL skip env ignored"; }
board "no count line here"
chk;                                      expect "unparseable board exits 0" 0
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   unparseable board is silent"; } || { fail=$((fail+1)); echo "FAIL output on unparseable board"; }
finish
