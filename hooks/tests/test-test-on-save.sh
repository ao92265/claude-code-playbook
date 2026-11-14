#!/bin/bash
# test-on-save.sh: editing a source file runs its sibling test file with the detected runner;
# test files, non-source files and sources without a test are skipped.
# Invocation only: the hook's failure exit reads the status of an unrelated `if`, see report.
source "$(dirname "$0")/lib.sh"
H=test-on-save.sh
W="$TD/w"; mkdir -p "$W/src" "$TD/bin"; cd "$W" || exit 1
for t in npx python go; do
cat > "$TD/bin/$t" <<STUB
#!/bin/bash
echo "$t \$*" >> "$TD/calls"
echo "stub output"
exit 1
STUB
chmod +x "$TD/bin/$t"
done
PATHX="PATH=$TD/bin:$PATH"
ed() { rm -f "$TD/calls"; run $H "$(file_payload Edit "$1")" "$PATHX"; }
ran() { grep -q "$1" "$TD/calls" 2>/dev/null; }
yes_() { if ran "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }
no_()  { if ran "$2"; then fail=$((fail+1)); echo "FAIL $1"; else pass=$((pass+1)); echo "ok   $1"; fi; }

touch src/foo.ts src/foo.test.ts
ed "$W/src/foo.ts";                       expect "ts without runner exits 0" 0
no_ "ts without runner runs nothing" "."
mkdir -p node_modules/.bin; touch node_modules/.bin/vitest
ed "$W/src/foo.ts"
yes_ "vitest runs the sibling test" "npx vitest run $W/src/foo.test.ts"
rm node_modules/.bin/vitest; touch node_modules/.bin/jest
ed "$W/src/foo.ts"
yes_ "jest used when only jest installed" "npx jest $W/src/foo.test.ts"
touch src/foo.test.test.ts   # a decoy so an unskipped test-file edit would find something to run
ed "$W/src/foo.test.ts";                  expect "test file edit skipped" 0
no_ "test file edit runs nothing" "."
touch src/bar.ts
ed "$W/src/bar.ts";                       expect "source without test skipped" 0
no_ "no test file runs nothing" "."
ed "$W/src/readme.md";                    expect "non-source skipped" 0
no_ "non-source runs nothing" "."
touch src/test_baz.py src/baz.py
ed "$W/src/baz.py"
yes_ "pytest runs for python sibling" "python -m pytest $W/src/test_baz.py"
touch src/q_test.go src/q.go
ed "$W/src/q.go"
yes_ "go test runs for go sibling" "go test"
finish
