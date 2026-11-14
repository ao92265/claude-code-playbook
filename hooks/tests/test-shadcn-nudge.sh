#!/bin/bash
# shadcn-nudge.sh: UI-building prompts in a shadcn project get a registry reminder; elsewhere silent.
source "$(dirname "$0")/lib.sh"
H=shadcn-nudge.sh
S="$TD/shop"; mkdir -p "$S/app/deep"; touch "$S/components.json"
P="$TD/plain"; mkdir -p "$P"
U="$TD/ui"; mkdir -p "$U/src/components/ui"
p() { jq -nc --arg p "$1" --arg c "$2" '{prompt:$p,cwd:$c}'; }

run $H "$(p 'build a dialog for settings' "$S")"; expect "shadcn project exits 0" 0
expect_has "nudges in shadcn project" "$OUT" "shadcn is available"
run $H "$(p 'Add a Button' "$S/app/deep")"
expect_has "found by walking up" "$OUT" "shadcn is available"
run $H "$(p 'create a tooltip' "$U")"
expect_has "src/components/ui marker works" "$OUT" "shadcn is available"
run $H "$(p 'build a dialog' "$P")"
expect_lacks "non-shadcn project silent" "$OUT" "shadcn"
run $H "$(p 'fix the database query' "$S")"
expect_lacks "no UI noun silent" "$OUT" "shadcn"
run $H "$(p 'the button looks fine' "$S")"
expect_lacks "no build verb silent" "$OUT" "shadcn"
run $H "$(p 'build a dialog' "$TD/missing")"; expect "missing cwd exits 0" 0
expect_lacks "missing cwd silent" "$OUT" "shadcn"
run $H "$(p 'build a dialog' "$S")" CLAUDE_SKIP_HOOKS=shadcn-nudge
expect_lacks "skip env silent" "$OUT" "shadcn"
finish
