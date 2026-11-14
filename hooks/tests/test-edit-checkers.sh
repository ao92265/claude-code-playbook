#!/bin/bash
# build-check, ts-check, lint-check, format-check: PostToolUse checkers that shell out to npx.
# Only the right file types in the right project shapes reach npx; a failing tool maps to the documented exit.
source "$(dirname "$0")/lib.sh"
W="$TD/w"; mkdir -p "$W" "$TD/bin"; cd "$W" || exit 1
cat > "$TD/bin/npx" <<STUB
#!/bin/bash
echo "\$*" >> "$TD/npx.calls"
echo "boom from npx"
exit \$(cat "$TD/npx.rc" 2>/dev/null || echo 0)
STUB
chmod +x "$TD/bin/npx"
PATHX="PATH=$TD/bin:$PATH"
ed() { run "$1" "$(file_payload Edit "$2")" "$PATHX"; }
called() { [[ -s "$TD/npx.calls" ]]; }
reset() { rm -f "$TD/npx.calls"; echo "${1:-0}" > "$TD/npx.rc"; }
check_called() { if called; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }
check_not_called() { if called; then fail=$((fail+1)); echo "FAIL $1"; else pass=$((pass+1)); echo "ok   $1"; fi; }

# --- build-check.sh
H=build-check.sh
reset 0; ed $H "$W/a.ts";                 expect "build: no tsconfig skips" 0
check_not_called "build: no tsconfig never runs tsc"
echo '{}' > tsconfig.json
ed $H "$W/a.ts";                          expect "build: clean tsc passes" 0
check_called "build: tsc ran for ts file"
reset 0; ed $H "$W/a.css";                expect "build: non-ts skipped" 0
check_not_called "build: non-ts never runs tsc"
reset 2; ed $H "$W/a.tsx";                expect "build: failing tsc blocks" 2
expect_has "build: tsc output surfaced" "$ERR" "boom from npx"
reset 0; run $H '{}' "$PATHX";            expect "build: no file path passes" 0

# --- ts-check.sh (invocation only: its pipeline exit code is head's, see report)
H=ts-check.sh
reset 0; ed $H "$W/a.md";                 expect "ts: non-ts skipped" 0
check_not_called "ts: non-ts never runs tsc"
ed $H "$W/a.ts";                          expect "ts: clean tsc passes" 0
check_called "ts: tsc ran for ts file"
rm tsconfig.json; reset 0; ed $H "$W/a.ts"; expect "ts: no tsconfig skips" 0
check_not_called "ts: no tsconfig never runs tsc"

# --- lint-check.sh (invocation only, same pipeline caveat)
H=lint-check.sh
reset 0; ed $H "$W/a.ts";                 expect "lint: no eslint config skips" 0
check_not_called "lint: no config never runs eslint"
touch eslint.config.js .eslintrc.json   # both needed: the hook's ls glob errors unless both patterns match
ed $H "$W/a.ts";                          expect "lint: eslint not installed skips" 0
check_not_called "lint: not installed never runs eslint"
mkdir -p node_modules/.bin; touch node_modules/.bin/eslint
ed $H "$W/a.py";                          expect "lint: non-js skipped" 0
check_not_called "lint: non-js never runs eslint"
ed $H "$W/a.jsx";                         expect "lint: clean eslint passes" 0
check_called "lint: eslint ran for jsx"

# --- format-check.sh
H=format-check.sh
rm node_modules/.bin/eslint
reset 0; ed $H "$W/a.ts";                 expect "format: no prettier skips" 0
check_not_called "format: no prettier never runs npx"
touch node_modules/.bin/prettier
ed $H "$W/a.ts";                          expect "format: clean file passes" 0
check_called "format: prettier ran"
reset 0; ed $H "$W/a.py";                 expect "format: non-formattable skipped" 0
check_not_called "format: py never runs prettier"
reset 1; ed $H "$W/a.json";               expect "format: dirty file warns" 1
expect_has "format: names the file" "$ERR" "Formatting issues in $W/a.json"
finish
