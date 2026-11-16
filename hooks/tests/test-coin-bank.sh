#!/bin/bash
# coin-bank.py: atomic read/modify/write of the coin state file; totals accumulate, a corrupt file resets to defaults.
source "$(dirname "$0")/lib.sh"
H=coin-bank.py
S="$HOME/.claude/hooks/coin-state.json"
j() { jq -r "$1" "$S"; }
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }
bank() { printf '' | env HOME="$HOME" python3 "$HOOKS_DIR/$H" "$@" >"$TD/out" 2>"$TD/err"; RC=$?; OUT=$(cat "$TD/out"); }

bank 5 100;                               expect "first earn exits 0" 0
check "state file created with totals" '[[ "$(j .total)" == 5 && "$(j .total_fed_in)" == 100 ]]'
check "last earn recorded" '[[ "$(j .last_earned)" == 5 && "$(j .last_fed_in)" == 100 ]]'
check "result printed as json" '[[ "$(printf "%s" "$OUT" | jq -r .total)" == 5 ]]'
bank 2 50
check "second earn accumulates" '[[ "$(j .total)" == 7 && "$(j .total_fed_in)" == 150 ]]'
check "last earn overwritten, not summed" '[[ "$(j .last_earned)" == 2 ]]'
echo '{not json' > "$S"
bank 3 10;                                expect "corrupt state exits 0" 0
check "corrupt state resets then counts" '[[ "$(j .total)" == 3 && "$(j .total_fed_in)" == 10 ]]'
bank;                                     expect "no args exits 0" 0
check "no args earns zero" '[[ "$(j .last_earned)" == 0 && "$(j .total)" == 3 ]]'
finish
