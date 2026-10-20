#!/bin/bash
# test-gate.py: a session that changed source code cannot stop until something
# has run that code (tests, a build, or the changed file itself) after the last
# change. Blocks once per session.
HOOK="$HOME/.claude/hooks/test-gate.py"
FAIL=0
T=$(mktemp -d)
ok() { [ "$1" -eq "$2" ] && echo "OK   $3" || { echo "FAIL $3 (want $1 got $2)"; FAIL=$((FAIL+1)); }; }
# Each event needs a later timestamp. ts runs in a subshell, so count in a file.
echo 0 > "$T/n"
ts() { n=$(( $(cat "$T/n") + 1 )); echo "$n" > "$T/n"; printf '2026-10-06T%02d:%02d:00.000Z' $((10 + n / 60)) $((n % 60)); }
edit() { jq -cn --arg t "$(ts)" --arg f "$1" '{type:"assistant", timestamp:$t, message:{content:[{type:"tool_use", name:"Edit", input:{file_path:$f}}]}}'; }
bash_() { jq -cn --arg t "$(ts)" --arg c "$1" '{type:"assistant", timestamp:$t, message:{content:[{type:"tool_use", name:"Bash", input:{command:$c}}]}}'; }
skill() { jq -cn --arg t "$(ts)" --arg s "$1" '{type:"assistant", timestamp:$t, message:{content:[{type:"tool_use", name:"Skill", input:{skill:$s}}]}}'; }
stop() { # want, label, session, transcript-file, [entrypoint], [stop_hook_active]
  jq -n --arg s "$3" --arg p "$4" --argjson a "${6:-false}" '{session_id:$s, transcript_path:$p, stop_hook_active:$a}' \
    | env -u CLAUDE_SKIP_HOOKS -u OMC_SKIP_HOOKS TEST_GATE_STATE="$T/state" TEST_GATE_LOG="$T/log" CLAUDE_CODE_ENTRYPOINT="${5:-cli}" python3 "$HOOK" >/dev/null 2>"$T/err"
  ok "$1" $? "$2"; }

: > "$T/a.jsonl"
stop 0 "no edits: passes" a "$T/a.jsonl"

{ edit /r/src/app.ts; } > "$T/b.jsonl"
stop 2 "source edit with nothing run after: blocked" b "$T/b.jsonl"
grep -q "TEST GATE" "$T/err"; ok 0 $? "block message names TEST GATE"
stop 0 "second stop in the same session: passes" b "$T/b.jsonl"

{ edit /r/src/app.py; bash_ "cd /r && pytest -q"; } > "$T/c.jsonl"
stop 0 "edit then tests: passes" c "$T/c.jsonl"

{ bash_ "cd /r && npm test"; edit /r/src/app.ts; } > "$T/d.jsonl"
stop 2 "tests then edit: blocked" d "$T/d.jsonl"

{ edit /r/tools/sync.py; bash_ "python3 /r/tools/sync.py --dry"; } > "$T/e.jsonl"
stop 0 "edit then run the changed file: passes" e "$T/e.jsonl"

{ edit /r/hooks/x.sh; bash_ "~/.claude/scripts/tests/test_x.sh"; } > "$T/f.jsonl"
stop 0 "edit then a test script: passes" f "$T/f.jsonl"

{ edit /r/README.md; } > "$T/g.jsonl"
stop 0 "docs-only edit: passes" g "$T/g.jsonl"

{ bash_ "cd /r && cat > src/new.ts <<'EOF'
export const x = 1
EOF"; } > "$T/h.jsonl"
stop 2 "shell write with nothing run after: blocked" h "$T/h.jsonl"

{ edit /r/src/app.ts; skill done; } > "$T/i.jsonl"
stop 0 "edit then /done skill: passes" i "$T/i.jsonl"

{ edit /r/src/app.ts; } > "$T/j.jsonl"
stop 0 "headless run: passes" j "$T/j.jsonl" sdk-ts
stop 0 "stop_hook_active: passes" j2 "$T/j.jsonl" cli true
stop 0 "missing transcript: passes" k "$T/nope.jsonl"

{ edit /r/scripts/deploy.sh; bash_ "curl -s -m5 http://127.0.0.1:7860/health_check"; } > "$T/n.jsonl"
stop 0 "edit then hitting the running app on localhost: passes" n "$T/n.jsonl"

{ edit /r/chart/x.py; bash_ "helm template ./chart | head"; } > "$T/o.jsonl"
stop 0 "edit then helm template: passes" o "$T/o.jsonl"

{ edit /r/src/app.ts; bash_ "curl -s https://example.com/docs"; } > "$T/p.jsonl"
stop 2 "fetching a remote page is not running it: blocked" p "$T/p.jsonl"

{ edit /r/src/app.ts; bash_ "git diff src/app.ts"; } > "$T/l.jsonl"
stop 2 "reading the changed file is not running it: blocked" l "$T/l.jsonl"

{ edit /r/src/app.ts; } > "$T/m.jsonl"
jq -n --arg p "$T/m.jsonl" '{session_id:"m", transcript_path:$p}' | CLAUDE_SKIP_HOOKS=test-gate TEST_GATE_STATE="$T/state" TEST_GATE_LOG="$T/log" python3 "$HOOK" >/dev/null 2>&1
ok 0 $? "kill switch: passes"

# Round 1 review: naming a file is not running it.
blk() { { edit /r/src/app.ts; bash_ "$2"; } > "$T/x.jsonl"; stop 2 "$1" "x$RANDOM" "$T/x.jsonl"; }
pas() { { edit /r/src/app.ts; bash_ "$2"; } > "$T/x.jsonl"; stop 0 "$1" "x$RANDOM" "$T/x.jsonl"; }
blk "commit message naming the file: blocked" "git commit -m 'fix app.ts'"
blk "vim on the file: blocked" "vim src/app.ts"
blk "full-path git diff: blocked" "/usr/bin/git diff src/app.ts"
blk "heredoc note naming the file: blocked" "cat > /r/NOTES.md <<EOF
changed app.ts
EOF"
blk "pip install pytest: blocked" "pip install pytest"
blk "grep for jest: blocked" "grep -rn jest package.json"
blk "which pytest: blocked" "which pytest"
{ edit /r/src/a.py; bash_ "python3 /r/data.py"; } > "$T/x.jsonl"; stop 2 "running data.py after editing a.py: blocked" x1a "$T/x.jsonl"
pas "pnpm run test: passes" "pnpm run test"
pas "npm run typecheck: passes" "npm run typecheck"
pas "go build: passes" "cd /r && go build ./..."
pas "gradlew test: passes" "./gradlew test"
pas "npm run dev: passes" "npm run dev"
pas "node --test: passes" "node --test"
pas "env prefix then pytest: passes" "cd /r && FOO=1 pytest -q"
{ edit /r/hooks/gate.py; bash_ "echo '{}' | python3 /r/hooks/gate.py"; } > "$T/x.jsonl"; stop 0 "piping input into the changed file: passes" x2 "$T/x.jsonl"
{ bash_ "pytest -q"; bash_ "python3 - <<'PY'
p='/r/src/app.py'; s=open(p).read(); open(p,'w').write(s)
PY"; } > "$T/x.jsonl"; stop 2 "inline patch script after tests is an edit, not a run: blocked" x3 "$T/x.jsonl"
{ bash_ "pytest -q"; bash_ "perl -pi -e 's/a/b/' /r/src/app.py"; } > "$T/x.jsonl"; stop 2 "perl -pi after tests: blocked" x4 "$T/x.jsonl"
{ edit /r/src/app.ts; jq -cn --arg t "$(ts)" '{type:"assistant", timestamp:$t, message:{content:[{type:"tool_use", name:"mcp__claude-in-chrome__navigate", input:{url:"http://localhost:5173/settings"}}]}}'; } > "$T/x.jsonl"
stop 0 "browser visit to localhost: passes" x5 "$T/x.jsonl"
{ bash_ "cd /r && cat > tools/run.sh <<'EOF'
echo hi
EOF
bash tools/run.sh"; } > "$T/x.jsonl"; stop 0 "write and run in one call: passes" x6 "$T/x.jsonl"
pas "curl to localhost inside command substitution: passes" 'id=$(curl -fsS "http://127.0.0.1:7860/api/v1/flows")'
# A failed edit does not count as an edit.
{ bash_ "pytest -q"; jq -cn --arg t "$(ts)" '{type:"assistant", timestamp:$t, message:{content:[{type:"tool_use", id:"tu1", name:"Edit", input:{file_path:"/r/src/app.py"}}]}}'; jq -cn --arg t "$(ts)" '{type:"user", timestamp:$t, message:{content:[{type:"tool_result", tool_use_id:"tu1", is_error:true, content:"blocked"}]}}'; } > "$T/x.jsonl"
stop 0 "failed edit after tests: passes" x7 "$T/x.jsonl"
# Same second, with and without fractions, still orders correctly.
{ jq -cn '{type:"assistant", timestamp:"2026-10-06T11:00:00.500Z", message:{content:[{type:"tool_use", name:"Edit", input:{file_path:"/r/src/app.ts"}}]}}'; jq -cn '{type:"assistant", timestamp:"2026-10-06T11:00:00Z", message:{content:[{type:"tool_use", name:"Bash", input:{command:"npm test"}}]}}'; } > "$T/x.jsonl"
stop 2 "tests at :00Z before an edit at :00.500Z: blocked" x8 "$T/x.jsonl"
# Subagent edit after the main session's tests still blocks.
{ bash_ "npm test"; } > "$T/sa.jsonl"; mkdir -p "$T/sa/subagents"; { edit /r/src/late.ts; } > "$T/sa/subagents/agent-1.jsonl"
stop 2 "subagent edit after main tests: blocked" sa "$T/sa.jsonl"
# Round 2 review.
{ bash_ "python3 - <<'PY'
import ast; ast.parse(open('/r/src/app.py').read())
PY"; } > "$T/x.jsonl"; stop 0 "read-only analysis heredoc is not an edit: passes" r1 "$T/x.jsonl"
{ edit /r/src/app.py; bash_ "pytest -q"; bash_ "git show HEAD:src/app.py | python3 -c 'import sys; print(len(sys.stdin.read()))'"; } > "$T/x.jsonl"; stop 0 "piped read-only python after tests: passes" r2 "$T/x.jsonl"
{ edit /r/src/app.py; jq -cn --arg t "$(ts)" '{type:"assistant", timestamp:$t, message:{content:[{type:"tool_use", id:"b1", name:"Bash", input:{command:"pytest -q"}}]}}'; jq -cn --arg t "$(ts)" '{type:"user", timestamp:$t, message:{content:[{type:"tool_result", tool_use_id:"b1", is_error:true, content:"Exit code 1"}]}}'; } > "$T/x.jsonl"
stop 0 "a failing test run still counts as a run: passes" r3 "$T/x.jsonl"
{ jq -cn --arg t "$(ts)" '{type:"assistant", timestamp:$t, message:{content:[{type:"tool_use", id:"e9", name:"Edit", input:{file_path:"/r/src/app.py"}}]}}'; jq -cn --arg t "$(ts)" '{type:"user", timestamp:$t, message:{content:[{type:"tool_result", tool_use_id:"e9", is_error:true, content:"refused"}]}}'; } > "$T/x.jsonl"
stop 0 "only edit failed: passes" r4 "$T/x.jsonl"
blk "commit message with parens naming a runner: blocked" 'git commit -m "guard (make it fail open)"'
blk "echo with tsc in parens: blocked" 'echo "build (tsc) passed"'
blk "grep for runner names: blocked" 'grep -E "(pytest|jest)" a.sh'
blk "commit message with a semicolon and pytest: blocked" 'git commit -m "x; pytest passes now"'
blk "npm ci is not a run: blocked" "npm ci"
blk "npm --version is not a run: blocked" "npm --version"
pas "timeout then pytest: passes" "timeout 120 pytest -q"
pas "sudo -u then pytest: passes" "sudo -u bob pytest"
pas "env -u then pytest: passes" "env -u X pytest"
pas "uv run pytest: passes" "uv run pytest"
pas "poetry run pytest: passes" "poetry run pytest"
pas "for loop running test scripts: passes" 'for t in tests/*.sh; do bash "$t"; done'
pas "if pytest: passes" "if pytest; then echo ok; fi"
pas "python3 -u -m pytest: passes" "python3 -u -m pytest"
pas "npm run integration: passes" "npm run integration"
{ bash_ "pytest -q"; bash_ "python3 <<'PY'
open('/r/src/app.py','w').write('x')
PY"; } > "$T/x.jsonl"; stop 2 "python3 << (no dash) writing after tests: blocked" r5 "$T/x.jsonl"
{ bash_ "pytest -q"; bash_ "perl -0777 -pi -e 's/a/b/' /r/src/app.py"; } > "$T/x.jsonl"; stop 2 "perl -0777 -pi after tests: blocked" r6 "$T/x.jsonl"
{ bash_ "pytest -q"; bash_ "perl -p -i -e 's/a/b/' /r/src/app.py"; } > "$T/x.jsonl"; stop 2 "perl -p -i after tests: blocked" r7 "$T/x.jsonl"
{ echo '[1,2]'; echo '{"message":"str"}'; edit /r/src/app.ts; } > "$T/x.jsonl"; stop 2 "odd transcript lines do not switch the gate off: blocked" r8 "$T/x.jsonl"

printf 'not json' | env -u CLAUDE_SKIP_HOOKS TEST_GATE_STATE="$T/state" TEST_GATE_LOG="$T/log" CLAUDE_CODE_ENTRYPOINT=cli python3 "$HOOK" >/dev/null 2>&1; ok 0 $? "junk stdin fails open"

grep -q "BLOCK" "$T/log" && grep -q "PASS" "$T/log"; ok 0 $? "log records passes and blocks"

rm -rf "$T"
echo "failures: $FAIL"; exit $FAIL
