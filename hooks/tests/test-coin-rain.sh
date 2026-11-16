#!/bin/bash
# coin-rain.sh: Stop hook banks coins (output tokens, minimum 1) and tokens fed in (input plus cache) from the
# last usage record, plays a sound, and opens the coin window only when none is running.
# afplay, osascript and pgrep are stubs; the hooks dir is a private copy so state never lands in the repo.
source "$(dirname "$0")/lib.sh"
H=coin-rain.sh
HK="$HOME/.claude/hooks"; mkdir -p "$HK/sounds" "$TD/bin"
cp "$HOOKS_DIR/coin-bank.py" "$HK/coin-bank.py"; : > "$HK/sounds/a.mp3"
S="$HK/coin-state.json"
for b in afplay osascript; do printf '#!/bin/bash\necho "%s" >> "%s/calls"\n' "$b" "$TD" > "$TD/bin/$b"; chmod +x "$TD/bin/$b"; done
printf '#!/bin/bash\nexit $(cat "%s/pgrep.rc")\n' "$TD" > "$TD/bin/pgrep"; chmod +x "$TD/bin/pgrep"
PATHX="PATH=$TD/bin:$PATH"
nap() { perl -e 'select(undef,undef,undef,$ARGV[0])' "$1"; }
wait_for() { local i=0; while [ $i -lt 40 ]; do grep -q "$1" "$TD/calls" 2>/dev/null && return 0; nap 0.1; i=$((i+1)); done; return 1; }
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }
j() { jq -r "$1" "$S"; }
T="$TD/t.jsonl"
cat > "$T" <<'JSONL'
{"type":"assistant","message":{"usage":{"input_tokens":1,"cache_read_input_tokens":1,"cache_creation_input_tokens":1,"output_tokens":9}}}
{"type":"assistant","message":{"usage":{"input_tokens":100,"cache_read_input_tokens":2000,"cache_creation_input_tokens":300,"output_tokens":42}}}
{"type":"user","message":{"content":"no usage on this line"}}
JSONL
P=$(jq -nc --arg t "$T" '{transcript_path:$t}')

: > "$TD/calls"; echo 1 > "$TD/pgrep.rc"
run $H "$P" "$PATHX";                     expect "coin run exits 0" 0
check "coins equal last output tokens" '[[ "$(j .total)" == 42 && "$(j .last_earned)" == 42 ]]'
check "fed in sums input and both cache counts" '[[ "$(j .last_fed_in)" == 2400 ]]'
check "a sound is played" 'wait_for afplay'
check "window opened when none running" 'wait_for osascript'
: > "$TD/calls"; echo 0 > "$TD/pgrep.rc"
run $H "$P" "$PATHX"
check "totals accumulate across turns" '[[ "$(j .total)" == 84 && "$(j .total_fed_in)" == 4800 ]]'
nap 0.5
check "window not reopened when already running" '! grep -q osascript "$TD/calls"'
run $H '{"transcript_path":"/nonexistent"}' "$PATHX"
check "no usage still earns the 1 coin minimum" '[[ "$(j .last_earned)" == 1 && "$(j .last_fed_in)" == 0 ]]'
finish
