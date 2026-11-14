#!/bin/bash
# auto-simplify.sh: git commit with a big staged diff gets a codex review; [P1] blocks (2), else passes.
source "$(dirname "$0")/lib.sh"
H=auto-simplify.sh
W="$TD/w"; mkdir -p "$W" "$TD/bin"; cd "$W" || exit 1
git init -q -b main .
big() { seq 1 80 > big.txt; git add big.txt; }
# stub codex: logs that it ran, prints the review text from $TD/review as an agent_message
cat > "$TD/bin/codex" <<STUB
#!/bin/bash
echo ran >> "$TD/codex.calls"
[ -f "$TD/codex.fail" ] && exit 1
jq -nc --arg t "\$(cat "$TD/review")" '{type:"item.completed",item:{type:"agent_message",text:\$t}}'
STUB
chmod +x "$TD/bin/codex"
PATHX="PATH=$TD/bin:$PATH"
C=$(bash_payload "git commit -m x")

big
echo "[P1] null deref in parse" > "$TD/review"
run $H "$C" "$PATHX";                     expect "P1 finding blocks commit" 2
expect_has "stderr says blocked" "$ERR" "Commit blocked"
expect_has "review text shown" "$ERR" "null deref"
echo "[P2] rename this" > "$TD/review"
run $H "$C" "$PATHX";                     expect "P2 only is advisory" 0
expect_has "advisory review still shown" "$ERR" "rename this"
run $H "$(bash_payload "git status")" "$PATHX"; expect "non-commit command ignored" 0
run $H "$C" "$PATHX" CLAUDE_SKIP_HOOKS=auto-simplify; expect "skip env honoured" 0
touch "$TD/codex.fail"
echo "[P1] x" > "$TD/review"
run $H "$C" "$PATHX"
[[ $RC != 2 ]] && { pass=$((pass+1)); echo "ok   codex failure never blocks"; } || { fail=$((fail+1)); echo "FAIL codex failure blocked"; }
rm "$TD/codex.fail"
rm -f "$TD/codex.calls"
git reset -q; git rm -q --cached big.txt 2>/dev/null; seq 1 10 > small.txt; git add small.txt
run $H "$C" "$PATHX";                     expect "tiny diff skipped" 0
[[ ! -f "$TD/codex.calls" ]] && { pass=$((pass+1)); echo "ok   tiny diff never calls codex"; } || { fail=$((fail+1)); echo "FAIL tiny diff called codex"; }
finish
