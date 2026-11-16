#!/bin/bash
# reboot-stamp.sh: PostToolUse on a file in the reboots dir stamps the identity block (Path/Branch/Session),
# repairs a missing Session line, leaves stamped files alone, and drops a same-terminal claim ticket. Never blocks.
source "$(dirname "$0")/lib.sh"
H=reboot-stamp.sh
CFG="$HOME/.claude"; mkdir -p "$CFG/reboots" "$CFG/scripts" "$CFG/sessions"; ln -s "$HOOKS_DIR" "$CFG/hooks"
# stand-in for the identity script the hook shells out to
cat > "$CFG/scripts/reboot-identity.sh" <<'STUB'
#!/bin/bash
echo "- Path: \`$1\`"
echo "- Branch: \`main\`"
[ -n "$2" ] && echo "- Session: $2"
STUB
chmod +x "$CFG/scripts/reboot-identity.sh"
W="$TD/w"; mkdir -p "$W"
ed() { run $H "$(jq -nc --arg f "$1" --arg c "$W" '{tool_input:{file_path:$f},cwd:$c}')" "${@:2}"; }

OUTSIDE="$TD/notes.md"; printf '# Title\nbody\n' > "$OUTSIDE"
ed "$OUTSIDE";                            expect "file outside reboots dir ignored" 0
expect_lacks "outside file untouched" "$(cat "$OUTSIDE")" "Path:"

R="$CFG/reboots/reboot-2026-11-05-0900-parser-fix.md"
printf '# Reboot title\n\nthe plan\n' > "$R"
ed "$R";                                  expect "stamp run exits 0" 0
BODY=$(cat "$R")
expect_has "path stamped" "$BODY" "- Path: \`$W\`"
expect_has "session stamped from filename slug" "$BODY" "- Session: parser-fix"
[[ "$(sed -n 1p "$R")" == "# Reboot title" ]] && { pass=$((pass+1)); echo "ok   block inserted after the H1"; } || { fail=$((fail+1)); echo "FAIL H1 moved"; }
expect_has "original body kept" "$BODY" "the plan"

# stamped file with no Session line gets one, in place
R2="$CFG/reboots/reboot-2026-11-05-0910-second-task.md"
printf '# T\n- Path: `/p`\n- Branch: `main`\n\nbody\n' > "$R2"
ed "$R2"
BODY=$(cat "$R2")
expect_has "missing session line repaired" "$BODY" "- Session: second-task"
[[ "$(sed -n 4p "$R2")" == "- Session: second-task" ]] && { pass=$((pass+1)); echo "ok   session line placed after Branch"; } || { fail=$((fail+1)); echo "FAIL session line misplaced"; }

# a file that already has a Session line is never rewritten
R3="$CFG/reboots/reboot-2026-11-05-0920-third.md"
printf '# T\n- Path: `/p`\n- Session: mine\n\nbody\n' > "$R3"
BEFORE=$(cat "$R3"); ed "$R3"
[[ "$(cat "$R3")" == "$BEFORE" ]] && { pass=$((pass+1)); echo "ok   stamped file untouched"; } || { fail=$((fail+1)); echo "FAIL stamped file rewritten"; }

# claim ticket: registry entry for an ancestor pid (this test shell) -> ticket points at the reboot file
echo '{"name":"mysess","nameSource":"explicit"}' > "$CFG/sessions/$$.json"
R4="$CFG/reboots/reboot-2026-11-05-0930-fourth.md"
printf '# T\n\nbody\n' > "$R4"
ed "$R4"
[[ "$(cat "$CFG/state/reboot-pending/$$" 2>/dev/null)" == "$R4" ]] && { pass=$((pass+1)); echo "ok   claim ticket names the file"; } || { fail=$((fail+1)); echo "FAIL claim ticket missing"; }
ed "$CFG/reboots/missing.md";             expect "missing file exits 0" 0
run $H '';                                expect "empty stdin exits 0" 0
finish
