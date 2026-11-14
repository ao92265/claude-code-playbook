#!/bin/bash
# tldr-mode.py: latches a per-session marker, sweeps old markers, never blocks.
source "$(dirname "$0")/lib.sh"
H=tldr-mode.py
ST="$HOME/.claude/state/register-gate"

run $H '{"session_id":"abc123"}';        expect "latch exits 0" 0
[[ -f "$ST/abc123.tldr" ]] && { pass=$((pass+1)); echo "ok   marker written"; } || { fail=$((fail+1)); echo "FAIL marker written"; }
expect_has "marker is an ISO timestamp" "$(cat "$ST/abc123.tldr" 2>/dev/null)" "Z"
run $H '{}';                              expect "no session exits 0" 0
[[ $(ls "$ST" | wc -l) -eq 1 ]] && { pass=$((pass+1)); echo "ok   no session writes nothing"; } || { fail=$((fail+1)); echo "FAIL no session writes nothing"; }
run $H 'not json';                        expect "bad json exits 0" 0
touch -t 202001010000 "$ST/old.tldr" "$ST/old.last" "$ST/old.streak" "$ST/keep.txt"
touch "$ST/fresh.last"
run $H '{"session_id":"other"}'
[[ ! -e "$ST/old.tldr" && ! -e "$ST/old.last" && ! -e "$ST/old.streak" ]] && { pass=$((pass+1)); echo "ok   stale markers swept"; } || { fail=$((fail+1)); echo "FAIL stale markers swept"; }
[[ -e "$ST/fresh.last" && -e "$ST/abc123.tldr" && -e "$ST/keep.txt" ]] && { pass=$((pass+1)); echo "ok   fresh and foreign files kept"; } || { fail=$((fail+1)); echo "FAIL fresh and foreign files kept"; }
run $H '{"session_id":"skipped"}' CLAUDE_SKIP_HOOKS=tldr-mode
[[ ! -e "$ST/skipped.tldr" ]] && { pass=$((pass+1)); echo "ok   skip env writes nothing"; } || { fail=$((fail+1)); echo "FAIL skip env writes nothing"; }
finish
