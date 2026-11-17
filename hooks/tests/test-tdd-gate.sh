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
mkdir -p "$W/src/test/java/com/acme"; touch "$W/src/test/java/com/acme/FooTest.java"
ed "$W/src/main/java/com/acme/Foo.java";  expect "java test deep under src/test passes" 0
mkdir -p "$W/tests/App.Tests"; touch "$W/tests/App.Tests/BarTests.cs"
ed "$W/src/Bar.cs";                       expect "cs test in tests/App.Tests passes (no repo)" 0
# A failing find (here: no src/test folder at all) must not end the hook early.
EMPTY="$TD/empty"; mkdir -p "$EMPTY"
( cd "$EMPTY" && run $H "$(file_payload Edit "$EMPTY/src/Nope.java")" TDD_GATE_BLOCK=1; echo "$RC" > "$TD/rc1" )
RC=$(cat "$TD/rc1");                      expect "java with no src/test still blocks in block mode" 2
( cd "$EMPTY" && run $H "$(file_payload Edit "$EMPTY/src/Nope.cs")" TDD_GATE_BLOCK=1; echo "$RC" > "$TD/rc2" )
RC=$(cat "$TD/rc2");                      expect "cs search still blocks in block mode" 2
# A repo-root search must not count a test that lives in a sibling worktree.
mkdir -p "$EMPTY/.claude/worktrees/other/src/test"; touch "$EMPTY/.claude/worktrees/other/src/test/NopeTest.java"
( cd "$EMPTY" && run $H "$(file_payload Edit "$EMPTY/src/Nope.java")"; echo "$RC" > "$TD/rc3" )
RC=$(cat "$TD/rc3");                      expect "test in a sibling worktree does not count" 1
# C# in a real repo: the search is scoped to that repo, whatever the current folder is.
R="$TD/repo"; mkdir -p "$R/src" "$R/tests"; git -C "$R" init -q 2>/dev/null
edat() { ( cd "$1" && run $H "$(file_payload Edit "$2")" "${@:3}"; echo "$RC" > "$TD/rcx" ); RC=$(cat "$TD/rcx"); }
touch "$R/tests/QuxTests.cs"
edat / "$R/src/Qux.cs";                   expect "cs test in its repo is found from another folder" 0
mkdir -p "$R/.worktrees/feat/tests"; git -C "$R/.worktrees/feat" init -q 2>/dev/null; touch "$R/.worktrees/feat/tests/BazTests.cs"
edat "$R" "$R/src/Baz.cs";                expect "cs test only in a .worktrees checkout does not count" 1
# Worktree folders are skipped outside a repo. The files sit within the 3 level
# search depth, so the skip rules are really what keeps them out.
mkdir -p "$EMPTY/.claude"; touch "$EMPTY/.claude/ZedTests.cs"
edat "$EMPTY" "$EMPTY/src/Zed.cs";        expect "cs test only in a .claude worktree does not count" 1
mkdir -p "$EMPTY/.worktrees"; touch "$EMPTY/.worktrees/YakTests.cs"
edat "$EMPTY" "$EMPTY/src/Yak.cs";        expect "cs test only in a plain .worktrees folder does not count" 1
mkdir -p "$EMPTY/worktrees"; touch "$EMPTY/worktrees/XylTests.cs"
edat "$EMPTY" "$EMPTY/src/Xyl.cs";        expect "cs test only in a worktrees folder does not count" 1
mkdir -p "$R/src/test/java/a"; touch "$R/src/test/java/a/FooTest.java"
edat / "$R/src/main/java/a/Foo.java";     expect "java test in its repo is found from another folder" 0
edat / "$R/src/main/java/brandnew/Foo.java"; expect "java in a folder that does not exist yet is found from another folder" 0
mkdir -p "$R/lib"; touch "$R/src/test/ZapTest.java"
edat / "$R/lib/newdir/Zap.java";          expect "java outside src/main in a new folder finds its repo" 0
# The test name has to match the whole file name, and glob characters are plain text.
touch "$R/tests/UserServiceTests.cs"
edat "$R" "$R/src/Service.cs";            expect "cs test for a longer name does not count" 1
touch "$R/tests/Gen1Tests.cs"
edat "$R" "$R/src/Gen[1].cs";             expect "cs name with glob characters is plain text" 1
# git quotes and escapes paths with accents or quotes unless asked not to.
mkdir -p "$R/tests/$(printf '\xc3\x9c')ber"; touch "$R/tests/$(printf '\xc3\x9c')ber/AlphaTests.cs"
edat "$R" "$R/src/Alpha.cs";              expect "cs test in an accented folder is found" 0
mkdir -p "$R/tests/q\"x"; touch "$R/tests/q\"x/GammaTests.cs"
edat "$R" "$R/src/Gamma.cs";              expect "cs test in a folder with a quote is found" 0
# Outside a repo, never search from the home folder or the root.
mkdir -p "$HOME/a/b"; touch "$HOME/a/b/HomeTests.cs"
edat "$HOME" "$HOME/Home.cs";             expect "cs search never starts from the home folder" 1
# An unreadable folder must not end the hook early either.
U="$TD/unread"; mkdir -p "$U/src" "$U/noread"; chmod 000 "$U/noread"
edat "$U" "$U/src/Locked.cs" TDD_GATE_BLOCK=1; expect "cs search over an unreadable folder still blocks" 2
chmod 755 "$U/noread"
ed "$W/src/style.css";                    expect "css skipped" 0
ed "$W/src/unknown.xyz";                  expect "unknown extension skipped" 0
run $H '{"tool_input":{}}';               expect "no file_path ok" 0
finish
