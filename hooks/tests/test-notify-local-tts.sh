#!/bin/bash
# notify-local-tts.sh: Stop hook speaks the last "Summary:" line of the reply (say fallback, or a bell in bell mode);
# mute file and missing transcript stay silent. say and afplay are stubs.
source "$(dirname "$0")/lib.sh"
H=notify-local-tts.sh
mkdir -p "$TD/bin" "$HOME/.claude" "$TD/h"
for b in say afplay; do printf '#!/bin/bash\necho "%s $*" >> "%s/calls"\n' "$b" "$TD" > "$TD/bin/$b"; chmod +x "$TD/bin/$b"; done
PATHX="PATH=$TD/bin:$PATH"
# the hook reads notification.conf from its own directory, so run a private copy with no conf (voice mode)
cp "$HOOKS_DIR/$H" "$TD/h/$H"
T="$TD/t.jsonl"
tr_() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}' > "$T"; }
go() { : > "$TD/calls"; HOOKS_DIR="$TD/h" run $H "$(jq -nc --arg t "${1:-$T}" '{transcript_path:$t}')" "$PATHX"; }
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }

tr_ $'Long answer here\nSummary: shipped the parser fix\nmore text'
go;                                       expect "voice run exits 0" 0
check "say speaks the summary text" '[[ "$(cat "$TD/calls")" == "say shipped the parser fix" ]]'
tr_ $'summary: first one\nSummary: second one'
go
check "last summary line wins, case insensitive" '[[ "$(cat "$TD/calls")" == "say second one" ]]'
tr_ "no summary line in this reply"
go
check "no summary stays silent" '[[ ! -s "$TD/calls" ]]'
tr_ "Summary: muted run"
touch "$HOME/.claude/tts-mute"
go
check "mute file stays silent" '[[ ! -s "$TD/calls" ]]'
rm "$HOME/.claude/tts-mute"
go "$TD/missing.jsonl";                   expect "missing transcript exits 0" 0
check "missing transcript stays silent" '[[ ! -s "$TD/calls" ]]'
printf 'mode=bell\nsound_path=%s/ping.wav\n' "$TD" > "$TD/h/notification.conf"; : > "$TD/ping.wav"
go
check "bell mode plays the configured sound, not speech" '[[ "$(cat "$TD/calls")" == "afplay $TD/ping.wav" ]]'
finish
