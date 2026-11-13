#!/bin/bash
# secret-scanner.py: credential-shaped content in writes (Pre) or tool output (Post).
source "$(dirname "$0")/lib.sh"
H=secret-scanner.py
# Fake credentials assembled from parts so this file does not trip the scanner itself.
AWS="AKIA""ABCDEFGHIJKLMNOP"
GHP="ghp_""abcdefghijklmnopqrstuvwxyzABCDEF0123"
PW='password = "hunter22x"'

pre() { jq -nc --arg t "$1" --arg f "$2" --arg c "$3" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{file_path:$f,content:$c}}'; }
post() { jq -nc --arg t "$1" --arg r "$2" '{hook_event_name:"PostToolUse",tool_name:$t,tool_input:{command:"cat x"},tool_response:$r}'; }

run $H "$(pre Write /p/a.ts "key=$AWS")";        expect "AWS key in Write blocked" 2
run $H "$(pre Write /p/a.ts "t=$GHP")";          expect "GitHub PAT blocked" 2
run $H "$(pre Edit /p/a.ts "$PW")";              expect "hardcoded password warns (1)" 1
run $H "$(pre Write /p/a.ts "k=sk_test_""abcdefghijklmnopqrstuv")"; expect "high-severity (Stripe test) blocks" 2
run $H "$(jq -nc --arg c "k=$AWS" '{tool_name:"Edit",tool_input:{file_path:"/p/a.ts",new_string:$c}}')"; expect "Edit new_string scanned" 2
run $H "$(pre Write /p/a.ts "const a = 1")";     expect "clean write ok" 0
run $H "$(pre Write /p/fixtures/a.ts "key=$AWS")"; expect "fixtures path allowed" 0
run $H "$(pre Read /p/a.ts "key=$AWS")";         expect "Pre on Read tool ignored" 0
run $H "$(jq -nc --arg c "k=$AWS" '{tool_name:"MultiEdit",tool_input:{file_path:"/p/a",edits:[{new_string:$c}]}}')"
expect "MultiEdit edits scanned" 2
run $H "$(post Bash "out $AWS")";                expect "AWS key in Bash output flagged" 2
expect_has "post message says radioactive" "$ERR" "radioactive"
run $H "$(post Edit "out $AWS")";                expect "Post on Edit tool ignored" 0
run $H "$(post Bash "nothing here")";            expect "clean output ok" 0
run $H "not json";                               expect "bad json ok" 0
run $H "$(pre Write /p/a.ts "key=$AWS")" SECRET_SCANNER_DISABLED=1; expect "disable env honoured" 0
finish
