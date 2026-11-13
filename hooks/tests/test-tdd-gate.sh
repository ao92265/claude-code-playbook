#!/bin/bash
# tdd-gate.sh: editing source with no matching test warns (1), blocks with TDD_GATE_BLOCK=1 (2).
source "$(dirname "$0")/lib.sh"
H=tdd-gate.sh
W="$TD/w"; mkdir -p "$W/src" "$W/tests"; cd "$W" || exit 1
ed() { run $H "$(file_payload Edit "$1")" "${@:2}"; }

ed "$W/src/foo.ts";                       expect "ts without test warns" 1
expect_has "warning names the file" "$ERR" "foo.ts"
ed "$W/src/foo.ts" TDD_GATE_BLOCK=1;      expect "block mode exits 2" 2
ed "$W/src/foo.ts" TDD_GATE_DISABLED=1;   expect "disable env honoured" 0
ed "$W/src/foo.py";                       expect "py without test warns" 1
ed "$W/src/foo.go";                       expect "go without test warns" 1
ed "$W/src/Foo.cs";                       expect "cs without test warns" 1
touch "$W/src/foo.test.ts";               ed "$W/src/foo.ts"; expect "sibling .test.ts passes" 0
touch "$W/src/only.spec.ts"; ed "$W/src/only.ts"; expect "sibling .spec.ts passes" 0
touch "$W/src/bar_test.go";               ed "$W/src/bar.go"; expect "go _test.go passes" 0
mkdir -p "$W/src/__tests__"; touch "$W/src/__tests__/baz.spec.ts"; ed "$W/src/baz.ts"; expect "__tests__ spec passes" 0
touch "$W/tests/test_qux.py";             ed "$W/src/qux.py"; expect "tests/test_x.py passes" 0
mkdir -p "$W/tests/unit"; touch "$W/tests/unit/deep.test.ts"; ed "$W/src/deep.ts"; expect "tests/**/ match passes" 0
ed "$W/src/foo.test.ts";                  expect "test file itself skipped" 0
ed "$W/README.md";                        expect "markdown skipped" 0
ed "$W/package.json";                     expect "json skipped" 0
ed "$W/src/migrations/001.ts";            expect "migrations skipped" 0
ed "$W/node_modules/x/index.js";          expect "node_modules skipped" 0
ed "$W/src/style.css";                    expect "css skipped" 0
ed "$W/src/unknown.xyz";                  expect "unknown extension skipped" 0
run $H '{"tool_input":{}}';               expect "no file_path ok" 0
finish
