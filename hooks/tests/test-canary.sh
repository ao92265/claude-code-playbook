#!/bin/bash
# canary.sh: injects the status-light instruction every prompt and never blocks.
source "$(dirname "$0")/lib.sh"
H=canary.sh
run $H '{"cwd":"/tmp/x"}';              expect "exits 0" 0
expect_has "asks for a status light" "$OUT" "status light"
expect_has "names the canary" "$OUT" "canary"
run $H '';                              expect "empty stdin exits 0" 0
expect_has "empty stdin still injects" "$OUT" "status light"
finish
