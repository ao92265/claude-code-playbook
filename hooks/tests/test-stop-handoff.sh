#!/bin/bash
# stop-handoff.sh: every turn writes a compact "where I left off" handoff (git state, real asks, last action,
# stated finish line, evidence ledger, open questions) and a per-session copy. Never blocks.
source "$(dirname "$0")/lib.sh"
H=stop-handoff.sh
CFG="$HOME/.claude"; mkdir -p "$CFG"; ln -s "$HOOKS_DIR" "$CFG/hooks"
W="$TD/w"; mkdir -p "$W"; cd "$W" || exit 1
G="git -c user.email=t@example.com -c user.name=t"
git init -q -b feat-x .; echo a > a.txt; git add a.txt; $G commit -q -m "first commit"
echo dirty > a.txt
T="$TD/sess-abc.jsonl"
cat > "$T" <<'JSONL'
{"type":"user","message":{"content":"please fix the parser"}}
{"type":"user","message":{"content":[{"type":"text","text":"<system-reminder>injected noise</system-reminder>"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"Looking at the parser now"}]}}
{"type":"user","message":{"content":[{"type":"text","text":"now add a test for it"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/x/parser.ts"}}]}}
JSONL
P=$(jq -nc --arg c "$W" --arg t "$T" '{cwd:$c,transcript_path:$t}')
OUTF() { ls "$CFG"/handoffs/*.md 2>/dev/null | grep -v compact | head -1; }

run $H "$P";                              expect "stop hook exits 0" 0
F=$(OUTF); BODY=$(cat "$F" 2>/dev/null)
expect_has "records branch" "$BODY" 'Branch: `feat-x`'
expect_has "records last commit" "$BODY" "first commit"
expect_has "counts dirty files" "$BODY" "Uncommitted: 1 file(s)"
expect_has "records real asks" "$BODY" "please fix the parser"
expect_has "records latest ask" "$BODY" "now add a test for it"
expect_lacks "injected noise filtered" "$BODY" "injected noise"
expect_has "records last action" "$BODY" "Edit /x/parser.ts"
expect_has "missing finish line is called out" "$BODY" "NOT STATED"
[[ -f "$CFG/handoffs/sessions/$(basename "$F" .md)__sess-abc.md" ]] && { pass=$((pass+1)); echo "ok   per-session copy written"; } || { fail=$((fail+1)); echo "FAIL no per-session copy"; }

# stated finish line, open question, evidence ledger
mkdir -p "$CFG/state/leg-scope" "$CFG/state/open-question" .claude/evidence
echo "line=ship the parser fix" > "$CFG/state/leg-scope/stated-sess-abc"
echo '{"questions":["which parser version?"]}' > "$CFG/state/open-question/sess-abc.json"
{
  echo '{"cmd":"npm test","tail":"12 passed, 0 failed","at":"2026-01-01T10:00:00Z"}'
  echo '{"cmd":"npm run lint","tail":"3 errors found","at":"2026-01-01T10:05:00Z"}'
} > .claude/evidence/runs.jsonl
run $H "$P";                              expect "second run exits 0" 0
BODY=$(cat "$F")
expect_has "finish line used as next intent" "$BODY" "ship the parser fix"
expect_lacks "no NOT STATED once set" "$BODY" "NOT STATED"
expect_has "open question surfaced" "$BODY" "which parser version?"
expect_has "passing run reads green" "$BODY" "green npm test"
expect_has "failing run reads RED" "$BODY" "RED   npm run lint"

# bad input never blocks
run $H 'not json at all';                 expect "garbage stdin exits 0" 0
finish
