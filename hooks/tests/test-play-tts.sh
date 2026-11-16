#!/bin/bash
# play-tts.sh: speaks text through piper then afplay (background); disabled flag exits quietly, missing voice model exits 1.
# piper and afplay are stubs.
source "$(dirname "$0")/lib.sh"
H=play-tts.sh
C="$HOME/.claude"; mkdir -p "$TD/bin" "$C/piper-voices" "$HOME/.local/bin"
printf '#!/bin/bash\ncat >/dev/null\nwhile [ $# -gt 0 ]; do [ "$1" = --output_file ] && echo wav > "$2"; echo "piper $1" >> "%s/calls"; shift; done\n' "$TD" > "$HOME/.local/bin/piper"
printf '#!/bin/bash\necho "afplay $*" >> "%s/calls"\n' "$TD" > "$TD/bin/afplay"
chmod +x "$HOME/.local/bin/piper" "$TD/bin/afplay"
PATHX="PATH=$TD/bin:$PATH"
nap() { perl -e 'select(undef,undef,undef,$ARGV[0])' "$1"; }
wait_for() { local i=0; while [ $i -lt 40 ]; do grep -q "$1" "$TD/calls" 2>/dev/null && return 0; nap 0.1; i=$((i+1)); done; return 1; }
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }
quiet() { nap 0.5; [[ ! -s "$TD/calls" ]]; }

: > "$TD/calls"; touch "$C/tts-disabled"
run $H "" "$PATHX" ;                      expect "disabled exits 0" 0
rm "$C/tts-disabled"
run $H "hello" "$PATHX";                  expect "missing voice model exits 1" 1
touch "$C/piper-voices/en_US-lessac-medium.onnx"
: > "$TD/calls"
run $H "" "$PATHX";                       expect "empty text exits 0" 0
check "empty text speaks nothing" 'quiet'
run $H "hello world" "$PATHX";            expect "speak run exits 0" 0
check "piper used the default voice model" 'wait_for "piper $C/piper-voices/en_US-lessac-medium.onnx"'
check "afplay played at the default volume" 'wait_for "afplay -v 0.1"'
: > "$TD/calls"; echo 0.5 > "$C/tts-volume.txt"
run $H "again" "$PATHX"
check "configured volume honoured" 'wait_for "afplay -v 0.5"'
finish
