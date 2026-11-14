#!/bin/bash
# precompact-handoff.sh: before compaction, append a snapshot (files edited, ask history, trigger) to the
# compact handoff; identity header written once; never blocks.
source "$(dirname "$0")/lib.sh"
H=precompact-handoff.sh
CFG="$HOME/.claude"; mkdir -p "$CFG"; ln -s "$HOOKS_DIR" "$CFG/hooks"
W="$TD/w"; mkdir -p "$W"; cd "$W" || exit 1
git init -q -b feat-y .
T="$TD/s.jsonl"
cat > "$T" <<'JSONL'
{"type":"user","message":{"content":"refactor the loader"}}
{"type":"user","message":{"content":[{"type":"text","text":"<system-reminder>noise</system-reminder>"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"/x/loader.ts"}},{"type":"tool_use","name":"Read","input":{"file_path":"/x/other.ts"}}]}}
JSONL
P=$(jq -nc --arg c "$W" --arg t "$T" '{cwd:$c,transcript_path:$t,trigger:"manual"}')
OUTF() { ls "$CFG"/handoffs/*.compact.md 2>/dev/null | head -1; }

run $H "$P";                              expect "precompact exits 0" 0
F=$(OUTF); BODY=$(cat "$F" 2>/dev/null)
expect_has "identity header has path" "$BODY" "- Path: \`$W\`"
expect_has "identity header has branch" "$BODY" 'Branch: `feat-y`'
expect_has "snapshot records trigger" "$BODY" "trigger: manual"
expect_has "lists edited file" "$BODY" '`/x/loader.ts`'
expect_lacks "read-only file not listed" "$BODY" "other.ts"
expect_has "lists ask history" "$BODY" "refactor the loader"
expect_lacks "injected noise filtered" "$BODY" "noise"
run $H "$P";                              expect "second compaction exits 0" 0
BODY=$(cat "$F")
[[ $(grep -c '^## Pre-compaction snapshot' "$F") == 2 ]] && { pass=$((pass+1)); echo "ok   snapshots accumulate"; } || { fail=$((fail+1)); echo "FAIL snapshots did not accumulate"; }
[[ $(grep -c '^# Pre-compaction handoff' "$F") == 1 ]] && { pass=$((pass+1)); echo "ok   header written once"; } || { fail=$((fail+1)); echo "FAIL header repeated"; }
run $H '';                                expect "empty stdin exits 0" 0
finish
