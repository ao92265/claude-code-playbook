#!/bin/bash
# Assertion checklist for no-new-dep.sh. Run before and after any change to it.
HOOK="$HOME/.claude/hooks/no-new-dep.sh"
TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT
pass=0; fail=0

# Pretty-printed, the way a real package.json is written on disk.
base='{
  "name": "t",
  "dependencies": {
    "react": "^19.0.0"
  },
  "devDependencies": {
    "vitest": "^2.0.0"
  }
}'

run() { # name expected_exit payload
  local name="$1" want="$2" payload="$3" got out
  out="$(printf '%s' "$payload" | bash "$HOOK" 2>&1)"; got=$?
  if [[ "$got" == "$want" ]]; then
    pass=$((pass+1)); printf 'ok   %-46s exit=%s\n' "$name" "$got"
  else
    fail=$((fail+1)); printf 'FAIL %-46s exit=%s want=%s\n' "$name" "$got" "$want"
    [[ -n "$out" ]] && printf '       %s\n' "$out" | head -4
  fi
}

pj="$TD/package.json"; printf '%s' "$base" > "$pj"

# 1. Edit that adds a new dependency -> warn (1)
run "Edit adds new dep" 1 "$(jq -nc --arg f "$pj" '{
  tool_name:"Edit", tool_input:{ file_path:$f,
    old_string:"\"react\": \"^19.0.0\"",
    new_string:"\"react\": \"^19.0.0\", \"uuid\": \"^11.0.0\"" }}')"

# 2. Edit that only bumps a version -> silent (0)
run "Edit bumps version only" 0 "$(jq -nc --arg f "$pj" '{
  tool_name:"Edit", tool_input:{ file_path:$f,
    old_string:"\"react\": \"^19.0.0\"",
    new_string:"\"react\": \"^19.2.0\"" }}')"

# 3. Edit that removes a dependency -> silent (0)
run "Edit removes a dep" 0 "$(jq -nc --arg f "$pj" '{
  tool_name:"Edit", tool_input:{ file_path:$f,
    old_string:"\"vitest\": \"^2.0.0\"", new_string:"" }}')"

# 4. Write with a new dependency -> warn (1)
run "Write adds new dep" 1 "$(jq -nc --arg f "$pj" --arg c \
  '{"name":"t","dependencies":{"react":"^19.0.0","lodash":"^4.17.0"},"devDependencies":{"vitest":"^2.0.0"}}' \
  '{tool_name:"Write", tool_input:{file_path:$f, content:$c}}')"

# 5. Write with identical deps -> silent (0)
run "Write, no dep change" 0 "$(jq -nc --arg f "$pj" --arg c "$base" \
  '{tool_name:"Write", tool_input:{file_path:$f, content:$c}}')"

# 6. A non-package.json file -> silent (0)
printf 'x' > "$TD/index.ts"
run "Non-manifest file" 0 "$(jq -nc --arg f "$TD/index.ts" '{
  tool_name:"Edit", tool_input:{file_path:$f, old_string:"x", new_string:"y"}}')"

# 7. Lockfile -> silent (0)
printf '{}' > "$TD/package-lock.json"
run "Lockfile" 0 "$(jq -nc --arg f "$TD/package-lock.json" '{
  tool_name:"Write", tool_input:{file_path:$f, content:"{\"a\":1}"}}')"

# 8. package.json that does not exist yet -> silent (0)
run "New project, no file on disk" 0 "$(jq -nc --arg f "$TD/nope/package.json" '{
  tool_name:"Write", tool_input:{file_path:$f, content:"{\"dependencies\":{\"x\":\"1\"}}"}}')"

# 9. Skip switch honoured -> silent (0)
out=$(printf '%s' "$(jq -nc --arg f "$pj" '{tool_name:"Edit", tool_input:{
  file_path:$f, old_string:"\"react\": \"^19.0.0\"",
  new_string:"\"react\": \"^19.0.0\", \"uuid\": \"^11.0.0\"" }}')" \
  | CLAUDE_SKIP_HOOKS=no-new-dep bash "$HOOK" 2>&1); got=$?
if [[ $got == 0 ]]; then pass=$((pass+1)); echo "ok   skip switch honoured                          exit=0"
else fail=$((fail+1)); echo "FAIL skip switch honoured                          exit=$got want=0"; fi

# 10. Warn mode never blocks: exit must be 1, never 2, without the opt-in.
out=$(printf '%s' "$(jq -nc --arg f "$pj" '{tool_name:"Edit", tool_input:{
  file_path:$f, old_string:"\"react\": \"^19.0.0\"",
  new_string:"\"react\": \"^19.0.0\", \"uuid\": \"^11.0.0\"" }}')" | bash "$HOOK" 2>&1); got=$?
if [[ $got == 1 ]]; then pass=$((pass+1)); echo "ok   default is warn, not block                    exit=1"
else fail=$((fail+1)); echo "FAIL default is warn, not block                    exit=$got want=1"; fi

# 11b. is-docker is an environment probe, not a type check. It must NOT be told
# to use Array.isArray. Regression guard for the over-broad is-* glob.
outd=$(printf '%s' "$(jq -nc --arg f "$pj" '{tool_name:"Edit", tool_input:{
  file_path:$f, old_string:"\"react\": \"^19.0.0\"",
  new_string:"\"react\": \"^19.0.0\", \"is-docker\": \"^3.0.0\"" }}')" | bash "$HOOK" 2>&1)
if grep -q "is-docker" <<<"$outd" && ! grep -qi "isArray\|typeof" <<<"$outd"; then
  pass=$((pass+1)); echo "ok   is-docker gets no type-check advice"
else
  fail=$((fail+1)); echo "FAIL is-docker gets no type-check advice"; echo "       $outd" | head -3
fi

# 11c. is-array still gets the real answer.
outa=$(printf '%s' "$(jq -nc --arg f "$pj" '{tool_name:"Edit", tool_input:{
  file_path:$f, old_string:"\"react\": \"^19.0.0\"",
  new_string:"\"react\": \"^19.0.0\", \"is-array\": \"^1.0.0\"" }}')" | bash "$HOOK" 2>&1)
if grep -q "Array.isArray" <<<"$outa"; then
  pass=$((pass+1)); echo "ok   is-array still gets Array.isArray"
else
  fail=$((fail+1)); echo "FAIL is-array still gets Array.isArray"; echo "       $outa" | head -3
fi

# 11d. Temporal is not in stable Node. Following that hint gives a ReferenceError,
# so the date suggestion must never name it.
outt=$(printf '%s' "$(jq -nc --arg f "$pj" '{tool_name:"Edit", tool_input:{
  file_path:$f, old_string:"\"react\": \"^19.0.0\"",
  new_string:"\"react\": \"^19.0.0\", \"date-fns\": \"^4.0.0\"" }}')" | bash "$HOOK" 2>&1)
if grep -q "Intl.DateTimeFormat" <<<"$outt" && ! grep -q "Temporal" <<<"$outt"; then
  pass=$((pass+1)); echo "ok   date advice does not name Temporal"
else
  fail=$((fail+1)); echo "FAIL date advice does not name Temporal"; echo "       $outt" | head -3
fi

# 11. The suggestion for a known package actually appears in the message.
if grep -q "crypto.randomUUID" <<<"$out"; then
  pass=$((pass+1)); echo "ok   names the built-in alternative"
else
  fail=$((fail+1)); echo "FAIL names the built-in alternative"; echo "       $out" | head -3
fi

# 12. Block mode opts in to exit 2.
got=$(printf '%s' "$(jq -nc --arg f "$pj" '{tool_name:"Edit", tool_input:{
  file_path:$f, old_string:"\"react\": \"^19.0.0\"",
  new_string:"\"react\": \"^19.0.0\", \"uuid\": \"^11.0.0\"" }}')" \
  | NO_NEW_DEP_BLOCK=1 bash "$HOOK" >/dev/null 2>&1; echo $?)
if [[ $got == 2 ]]; then pass=$((pass+1)); echo "ok   NO_NEW_DEP_BLOCK=1 blocks                     exit=2"
else fail=$((fail+1)); echo "FAIL NO_NEW_DEP_BLOCK=1 blocks                     exit=$got want=2"; fi

echo
echo "passed $pass, failed $fail"
[[ $fail == 0 ]]
