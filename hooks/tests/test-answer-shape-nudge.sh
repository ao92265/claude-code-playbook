#!/bin/bash
# answer-shape-nudge.sh: injects the answer-shape rules every prompt, except in the exempt workspace.
source "$(dirname "$0")/lib.sh"
H=answer-shape-nudge.sh

run $H '{"prompt":"hi","cwd":"/tmp/proj"}';   expect "normal cwd exits 0" 0
expect_has "injects the dash ban" "$OUT" "NO em dashes"
expect_has "injects the length rule" "$OUT" "LENGTH"
expect_has "injects the missing rule" "$OUT" "MISSING"
run $H '{"prompt":"hi"}';                      expect "no cwd still injects" 0
expect_has "no cwd injects rules" "$OUT" "NO em dashes"
run $H "{\"cwd\":\"$HOME/.openalice\"}";       expect "exempt workspace exits 0" 0
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   exempt workspace silent"; } || { fail=$((fail+1)); echo "FAIL exempt workspace silent"; }
run $H "{\"cwd\":\"$HOME/.openalice/sub/dir\"}"; expect "exempt subdir exits 0" 0
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   exempt subdir silent"; } || { fail=$((fail+1)); echo "FAIL exempt subdir silent"; }
run $H "{\"cwd\":\"$HOME/.openalice-other\"}"; expect "lookalike dir exits 0" 0
expect_has "lookalike dir still injects" "$OUT" "NO em dashes"
finish
