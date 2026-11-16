#!/bin/bash
# daydream-surface.sh: prints a pending digest once, archives it, clears it, never blocks.
source "$(dirname "$0")/lib.sh"
H=daydream-surface.sh
DD="$HOME/.claude/daydreams"; mkdir -p "$DD"

run $H '{}';                                   expect "nothing pending exits 0" 0
expect_lacks "nothing pending prints nothing" "$OUT" "Daydreams"

printf 'idea one\nidea two\n' > "$DD/digest-pending.md"
run $H '{}';                                   expect "pending digest exits 0" 0
expect_has "prints the digest" "$OUT" "idea two"
expect_has "frames it as daydreams" "$OUT" "Daydreams while you were away"
expect_has "archives it" "$(cat "$DD/digest-archive.md")" "idea one"
[[ -s "$DD/digest-pending.md" ]] && RC=1 || RC=0; expect "clears the pending file" 0

run $H '{}'
expect_lacks "second run does not repeat it" "$OUT" "idea one"

printf 'safe\033]52;c;evil\007text\n' > "$DD/digest-pending-bets.md"
run $H '{}'
expect_lacks "strips escape sequences" "$OUT" $'\033'
expect_has "keeps the plain text" "$OUT" "safe"

printf 'kept\n' > "$DD/digest-pending.md"
run $H '{}' DAYDREAM_CHILD=1
expect_lacks "daydream child does not consume it" "$OUT" "kept"
run $H '{}' CLAUDE_SKIP_HOOKS=daydream
expect_lacks "skip switch honoured" "$OUT" "kept"
expect_has "pending file left for the real session" "$(cat "$DD/digest-pending.md")" "kept"
run $H '{}' CLAUDE_DISABLE_HOOKS=1
expect_lacks "disable switch honoured" "$OUT" "kept"

: > "$DD/digest-pending.md"
mkdir -p "$HOME/.claude/tune"; printf 'tune idea\n' > "$HOME/.claude/tune/digest-pending.md"
run $H '{}'
expect_has "surfaces the tune digest" "$OUT" "tune idea"
finish
