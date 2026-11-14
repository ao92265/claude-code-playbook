#!/bin/bash
# codex-prepush-review.sh: git push with a diff vs main gets a codex review; [P1] blocks (2).
source "$(dirname "$0")/lib.sh"
H=codex-prepush-review.sh
W="$TD/w"; mkdir -p "$W" "$TD/bin"; cd "$W" || exit 1
G="git -c user.email=t@example.com -c user.name=t"
git init -q -b main .
echo a > a.txt; git add a.txt; $G commit -q -m base
cat > "$TD/bin/codex" <<STUB
#!/bin/bash
echo ran >> "$TD/codex.calls"
[ -f "$TD/codex.fail" ] && exit 1
jq -nc --arg t "\$(cat "$TD/review")" '{type:"item.completed",item:{type:"agent_message",text:\$t}}'
STUB
chmod +x "$TD/bin/codex"
PATHX="PATH=$TD/bin:$PATH"
P=$(bash_payload "git push origin HEAD")

run $H "$P" "$PATHX";                     expect "no diff vs main passes" 0
[[ ! -f "$TD/codex.calls" ]] && { pass=$((pass+1)); echo "ok   no diff never calls codex"; } || { fail=$((fail+1)); echo "FAIL no diff called codex"; }
git checkout -q -b feat; echo b > b.txt; git add b.txt; $G commit -q -m feat
echo "[P1] data loss on retry" > "$TD/review"
run $H "$P" "$PATHX";                     expect "P1 blocks push" 2
expect_has "stderr says push blocked" "$ERR" "Push blocked"
expect_has "review shown" "$ERR" "data loss"
echo "[P3] nit" > "$TD/review"
run $H "$P" "$PATHX";                     expect "P3 only is advisory" 0
run $H "$(bash_payload "git log")" "$PATHX"; expect "non-push command ignored" 0
run $H "$P" "$PATHX" CLAUDE_SKIP_HOOKS=codex-prepush-review; expect "skip env honoured" 0
touch "$TD/codex.fail"; echo "[P1] x" > "$TD/review"
run $H "$P" "$PATHX"
[[ $RC != 2 ]] && { pass=$((pass+1)); echo "ok   codex failure never blocks"; } || { fail=$((fail+1)); echo "FAIL codex failure blocked"; }
rm "$TD/codex.fail"
git branch -q -m main trunk
run $H "$P" "$PATHX";                     expect "no main or master passes" 0
finish
