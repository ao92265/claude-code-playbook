#!/bin/bash
# factual-guardrail-nudge.sh: prints the guardrails on factual prompts, silent otherwise, never blocks.
source "$(dirname "$0")/lib.sh"
H=factual-guardrail-nudge.sh
pr() { run $H "$(jq -nc --arg p "$1" '{prompt:$p}')"; }

pr "please summarise this report";  expect "summarise: exit 0" 0; expect_has "summarise nudged" "$OUT" "factual_guardrails"
pr "Who wrote this library?";       expect_has "who wrote nudged" "$OUT" "factual_guardrails"
pr "fact-check this";         expect_has "fact-check nudged" "$OUT" "factual_guardrails"
pr "rename the variable foo";       expect "code prompt: exit 0" 0; expect_lacks "code prompt silent" "$OUT" "guardrails"
run $H '{}';                        expect "no prompt: exit 0" 0; expect_lacks "no prompt silent" "$OUT" "guardrails"
run $H 'garbage';                   expect "bad json: exit 0" 0
finish
