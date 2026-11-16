#!/bin/bash
# register-gate.py: Stop hook. Blocks replies with dashes, walls of text, or jargon overload; warns on near-misses.
source "$(dirname "$0")/lib.sh"
H=register-gate.py
ST="$HOME/.claude/state/register-gate"
EM=$(printf '\xe2\x80\x94')
words() { local i out=""; for ((i=0;i<$1;i++)); do out="$out word"; done; printf '%s' "${out# }"; }
mk() { # <session> <user prompt> <assistant text> [entrypoint]
  local f="$TD/t-$1.jsonl"
  { jq -nc --arg u "$2" '{type:"user",message:{content:$u}}'
    jq -nc --arg a "$3" --arg e "${4:-}" '{type:"assistant",entrypoint:$e,message:{content:[{type:"text",text:$a}]}}'; } > "$f"
  echo "$f"
}
stop() { # <session> <prompt> <reply> [VAR=val ...]
  local s="$1" p="$2" r="$3"; shift 3
  run $H "$(jq -nc --arg s "$s" --arg t "$(mk "$s" "$p" "$r")" '{session_id:$s,transcript_path:$t}')" "$@"
}

stop s1 "do it" "Done. The parser now handles empty input.";   expect "short plain reply passes" 0
stop s2 "do it" "That is fine $EM mostly.";                     expect "em dash blocks" 2
expect_has "dash message names the rule" "$ERR" "rule 6"
stop s2 "do it" "That is fine $EM mostly.";                     expect "same blocked text not blocked twice" 0
stop s3 "do it" 'Use `a'"$EM"'b` as the name.';                 expect "dash in inline code passes" 0
stop s4 "do it" "$(printf 'Look:\n```\nx %s y\n```\nok' "$EM")"; expect "dash in code fence passes" 0
stop s5 "do it" "$(words 300)";                                 expect "long plain wall blocks" 2
expect_has "length message" "$ERR" "that reply was 300 words"
stop s6 "please explain how this works" "$(words 300)";         expect "depth request lifts the ceiling" 0
stop s7 "explain it in plain english" "$(words 300)";          expect "plain request cancels depth" 2
stop s8 "do it" "$(words 100)";                                 expect "near miss passes" 0
[[ -f "$ST/s8.warn" ]] && { pass=$((pass+1)); echo "ok   near miss leaves a warn marker"; } || { fail=$((fail+1)); echo "FAIL near miss leaves a warn marker"; }
printf '%s' '{"session_id":"s8"}' | python3 "$HOOKS_DIR/$H" --prompt >"$TD/o" 2>&1
expect_has "next prompt gets the nudge" "$(cat "$TD/o")" "REGISTER: your last reply was 100 words"
printf '%s' '{"session_id":"s8"}' | python3 "$HOOKS_DIR/$H" --prompt >"$TD/o" 2>&1
[[ -z "$(cat "$TD/o")" ]] && { pass=$((pass+1)); echo "ok   nudge is spent after one use"; } || { fail=$((fail+1)); echo "FAIL nudge is spent after one use"; }
JARGON="$(words 100) see src/a/b.ts and run npm test then exit 1 with --force"
stop s9 "do it" "$JARGON";                                      expect "long and jargon heavy blocks" 2
expect_has "overload message" "$ERR" "technical references"
stop s10 "explain how this works" "$JARGON";                    expect "depth request waives jargon check" 0
stop s11 "do it" "$(words 30) see src/a/b.ts and run npm test then exit 1 with --force"; expect "short jargon passes" 0
stop s12 "do it" "$(printf '%s\n```\n%s\n```' "ok" "$(words 300)")"; expect "mostly code passes" 0
run $H "$(jq -nc --arg s s13 --arg t "$(mk s13 'do it' "x $EM y" cli)" '{session_id:$s,transcript_path:$t}')"
expect "interactive entrypoint still blocks" 2
run $H "$(jq -nc --arg s s14 --arg t "$(mk s14 'do it' "x $EM y" sdk-py)" '{session_id:$s,transcript_path:$t}')"
expect "headless entrypoint passes" 0
stop s15 "do it" "x $EM y" CLAUDE_SKIP_HOOKS=register-gate;  expect "skip env passes" 0
run $H "$(jq -nc --arg s s16 --arg t "$(mk s16 'do it' "x $EM y")" --arg c "$HOME/.openalice/w" '{session_id:$s,transcript_path:$t,cwd:$c}')"
expect "exempt workspace passes" 0
mkdir -p "$ST"; echo 2 > "$ST/s17.streak"
run $H "$(jq -nc --arg s s17 --arg t "$(mk s17 'do it' "x $EM y")" '{session_id:$s,transcript_path:$t,stop_hook_active:true}')"
expect "loop guard stands down after two blocks" 0
echo 1 > "$ST/s18.streak"
run $H "$(jq -nc --arg s s18 --arg t "$(mk s18 'do it' "x $EM y")" '{session_id:$s,transcript_path:$t,stop_hook_active:true}')"
expect "loop guard not yet reached still blocks" 2
echo "2020-01-01T00:00:00.000Z" > "$ST/s19.tldr"
stop s19 "do it" "$(words 160)";                                expect "tldr latch lowers the ceiling" 2
expect_has "tldr message" "$ERR" "asked for a tldr"
run $H '{"session_id":"s20","transcript_path":"/nonexistent"}'; expect "missing transcript passes" 0
run $H 'garbage';                                               expect "bad json passes" 0
finish
