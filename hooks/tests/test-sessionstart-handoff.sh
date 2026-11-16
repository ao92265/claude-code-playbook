#!/bin/bash
# sessionstart-handoff.sh: a fresh session gets the last handoff re-injected as SessionStart JSON; resume does not;
# stale or foreign files are not injected; a rich reboot is injected once, only to its owner.
source "$(dirname "$0")/lib.sh"
H=sessionstart-handoff.sh
CFG="$HOME/.claude"; mkdir -p "$CFG/handoffs" "$CFG/reboots"; ln -s "$HOOKS_DIR" "$CFG/hooks"
G="git -c user.email=t@example.com -c user.name=t"
W="$TD/w"; mkdir -p "$W"; cd "$W" || exit 1
git init -q -b feat-z .; echo a > a.txt; git add a.txt; $G commit -q -m "base commit"
OTHER="$TD/other"; mkdir -p "$OTHER"; ( cd "$OTHER" && git init -q -b feat-z . )
ctx() { printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
start() { run $H "$(jq -nc --arg c "$W" --arg s "$1" --arg i "${2:-}" '{cwd:$c,source:$s} + (if $i=="" then {} else {session_id:$i} end)')" "${@:3}"; }

start startup;                            expect "nothing to inject exits 0" 0
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   no handoff means no output"; } || { fail=$((fail+1)); echo "FAIL output with nothing to inject: $(printf '%s' "$OUT" | head -c 300)"; }

# write a real handoff with the sibling stop hook so the key round trip is covered
echo '{"cwd":"'"$W"'"}' | env HOME="$HOME" bash "$HOOKS_DIR/stop-handoff.sh"
printf 'notes line\033]52;c;evil\007 end\n' > SESSION_NOTES.md
start startup
expect_has "handoff re-injected" "$(ctx)" "Last session handoff (auto)"
expect_has "handoff carries the branch" "$(ctx)" 'Branch: `feat-z`'
expect_has "tells the model to verify" "$(ctx)" "Verify branch/dirty state"
expect_has "session notes injected" "$(ctx)" "notes line"
[[ "$(ctx)" != *$'\033'* ]] && { pass=$((pass+1)); echo "ok   escape bytes stripped"; } || { fail=$((fail+1)); echo "FAIL escape byte survived"; }
rm SESSION_NOTES.md
start resume;                             expect "resume exits 0" 0
[[ -z "$OUT" ]] && { pass=$((pass+1)); echo "ok   resume injects nothing"; } || { fail=$((fail+1)); echo "FAIL resume injected"; }
F=$(ls "$CFG"/handoffs/*.md | head -1)
touch -t 202001010000 "$F"
start startup
expect_lacks "stale handoff not injected" "$(ctx)" "Last session handoff"

# explicit restore file wins on startup
echo "restore body marker" > "$TD/restore.md"
start startup "" RESTORE_HANDOFF="$TD/restore.md"
expect_has "restore file injected" "$(ctx)" "restore body marker"
start clear "" RESTORE_HANDOFF="$TD/restore.md"
expect_lacks "restore file ignored after clear" "$(ctx)" "restore body marker"

# rich reboot: owned file injected once, foreign file never
RB="$CFG/reboots/reboot-2026-11-01-1000-parser-fix.md"
printf '# Reboot\n- Path: `%s`\n- Branch: `feat-z`\n\nresume the parser fix\n' "$W" > "$RB"
FOREIGN="$CFG/reboots/reboot-2026-11-02-1100-elsewhere.md"
printf '# Reboot\n- Path: `%s`\n- Branch: `feat-z`\n\nforeign plan marker\n' "$OTHER" > "$FOREIGN"
start clear sess-1
expect_has "owned reboot injected" "$(ctx)" "resume the parser fix"
expect_lacks "foreign reboot not injected" "$(ctx)" "foreign plan marker"
expect_has "session titled from slug" "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.sessionTitle // empty')" "parser-fix"
expect_has "autostart message after clear" "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.initialUserMessage // empty')" "Continue from the reboot handoff"
start clear sess-2
expect_lacks "reboot consumed after one real start" "$(ctx)" "resume the parser fix"
# a probe without a session id looks but does not spend
RB2="$CFG/reboots/reboot-2026-11-03-1200-second.md"
printf '# Reboot\n- Path: `%s`\n- Branch: `feat-z`\n\nsecond plan marker\n' "$W" > "$RB2"
start startup
expect_has "probe sees the reboot" "$(ctx)" "second plan marker"
[[ $(ls "$CFG"/state/reboot-consumed | wc -l) -eq 1 ]] && { pass=$((pass+1)); echo "ok   probe did not spend it"; } || { fail=$((fail+1)); echo "FAIL probe spent the reboot"; }
finish
