#!/bin/bash
# verify-gate.sh: --auto-arm/--arm capture a tsc baseline; Stop mode blocks (2) on a tsc regression or failing tests,
# and on 2+ edited source files that nothing reviewed (once per session).
source "$(dirname "$0")/lib.sh"
H=verify-gate.sh
STUB="$TD/bin"; mkdir -p "$STUB"
cat > "$STUB/npx" <<'S'
#!/bin/bash
i=0; while [ "$i" -lt "${TSC_ERRORS:-0}" ]; do echo "src/a.ts(1,1): error TS2322: bad"; i=$((i+1)); done; exit 0
S
cat > "$STUB/npm" <<'S'
#!/bin/bash
exit "${NPM_RC:-0}"
S
chmod +x "$STUB/npx" "$STUB/npm"
export PATH="$STUB:$PATH"
R="$TD/repo"; mkdir -p "$R"; cd "$R" || exit 1
git init -q . ; git config user.email t@example.com; git config user.name t
echo '{"name":"x","scripts":{"test":"jest"}}' > package.json; echo '{}' > tsconfig.json
git add -A; git commit -qm init
ST="$R/.claude/state"
# vg <mode-or-empty> <stdin> [VAR=val ...]
vg() { local m="$1" in="$2"; shift 2; printf '%s' "$in" | env "$@" bash "$HOOKS_DIR/verify-gate.sh" $m >"$TD/out" 2>"$TD/err"; RC=$?; OUT=$(cat "$TD/out"); ERR=$(cat "$TD/err"); }
edp() { jq -nc --arg f "$1" '{tool_input:{file_path:$f}}'; }
has() { [ -e "$1" ]; }
waitfor() { local i=0; while [ ! -e "$1" ] && [ $i -lt 40 ]; do sleep 0.1; i=$((i+1)); done; }
reset() { rm -r "$ST" 2>/dev/null; true; }

# --auto-arm
vg --auto-arm "$(edp /w/readme.md)";            expect "auto-arm on non-source exits 0" 0
has "$ST/needs-verify"; expect_has "non-source edit does not arm" "$?" "1"
vg --auto-arm "$(edp /w/a.ts)" TSC_ERRORS=3;    expect "auto-arm exits 0" 0
has "$ST/needs-verify"; expect_has "source edit arms the flag" "$?" "0"
waitfor "$ST/verify-baseline"
expect_has "baseline captures tsc error count" "$(cat "$ST/verify-baseline" 2>/dev/null)" "tsc_errors=3"
reset
vg --arm "" TSC_ERRORS=2;                       expect "--arm exits 0" 0
expect_has "--arm writes baseline synchronously" "$(cat "$ST/verify-baseline")" "tsc_errors=2"
reset

# Stop mode with a flag: regression blocks, equal passes
mkdir -p "$ST"; touch "$ST/needs-verify"
vg "" '' TSC_ERRORS=1;                          expect "no baseline passes and clears the flag" 0
has "$ST/needs-verify"; expect_has "flag cleared when baseline missing" "$?" "1"
mkdir -p "$ST"; touch "$ST/needs-verify"; echo tsc_errors=0 > "$ST/verify-baseline"
vg "" '' TSC_ERRORS=2;                          expect "tsc regression blocks" 2
expect_has "message says verification failed" "$ERR" "VERIFICATION FAILED"
echo tsc_errors=2 > "$ST/verify-baseline"
vg "" '' TSC_ERRORS=2 NPM_RC=1;                 expect "failing tests block" 2
expect_has "message says tests failed" "$ERR" "tests failed"
vg "" '' TSC_ERRORS=2 NPM_RC=0;                 expect "no regression and green tests pass" 0
has "$ST/needs-verify"; expect_has "flag cleared on pass" "$?" "1"
reset

# done-receipt nudge
echo dirty > "$R/new.txt"
vg "" '';                                       expect_has "uncommitted work and no receipt nudges" "$OUT" "done-receipt"
mkdir -p "$R/.omc/state"; touch "$R/.omc/state/done-receipt"
vg "" '';                                       expect_lacks "fresh receipt silences the nudge" "$OUT" "done-receipt"
rm "$R/new.txt"; rm -r "$R/.omc"

# review gate: 2+ edited source files with no review
TR="$TD/tr.jsonl"
N=0
tl() { N=$((N+1)); jq -nc --arg t "$(printf '2026-01-01T00:00:%02dZ' "$N")" --arg n "$1" --argjson i "$2" '{timestamp:$t,message:{content:[{type:"tool_use",name:$n,input:$i}]}}'; }
stopp() { jq -nc --arg s "$1" --arg t "$TR" '{session_id:$s,transcript_path:$t}'; }
{ tl Edit '{"file_path":"/w/src/a.ts"}'; } > "$TR"
vg "" "$(stopp one)";                           expect "single edited file passes" 0
{ tl Edit '{"file_path":"/w/src/a.ts"}'; tl Edit '{"file_path":"/w/src/b.ts"}'; } > "$TR"
vg "" "$(stopp two)";                           expect "two edited files with no review block" 2
expect_has "message says REVIEW GATE" "$ERR" "REVIEW GATE"
vg "" "$(stopp two)";                           expect "blocks once per session" 0
{ tl Edit '{"file_path":"/w/src/a.ts"}'; tl Edit '{"file_path":"/w/src/b.ts"}'; tl Agent '{"subagent_type":"code-reviewer"}'; } > "$TR"
vg "" "$(stopp rev)";                           expect "review after the edits passes" 0
{ tl Agent '{"subagent_type":"code-reviewer"}'; tl Edit '{"file_path":"/w/src/a.ts"}'; tl Edit '{"file_path":"/w/src/b.ts"}'; } > "$TR"
vg "" "$(stopp early)";                         expect "review before the edits does not count" 2
{ tl Bash '{"command":"cat > /w/src/a.ts"}'; tl Bash '{"command":"echo x > /w/src/b.py"}'; } > "$TR"
vg "" "$(stopp shell)";                         expect "shell redirects count as edits" 2
{ tl Edit '{"file_path":"/w/src/a.ts"}'; tl Edit '{"file_path":"/w/notes.md"}'; } > "$TR"
vg "" "$(stopp doc)";                           expect "markdown is not a source edit" 0
{ tl Edit '{"file_path":"/w/src/a.ts"}'; tl Edit '{"file_path":"/w/src/b.ts"}'; } > "$TR"
vg "" "$(jq -c '. + {stop_hook_active:true}' <<<"$(stopp active)")"; expect "stop_hook_active passes" 0
finish
