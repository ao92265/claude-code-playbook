#!/bin/bash
# pre-commit-verify.sh: a commit command runs the verification bundle (ci:local, else tsc/lint) and blocks (2) on failure;
# WIP markers and DONE_GATE_SKIP bypass; a pass writes a done receipt.
source "$(dirname "$0")/lib.sh"
H=pre-commit-verify.sh
W="$TD/w"; mkdir -p "$W" "$TD/bin"; cd "$W" || exit 1
git init -q -b main .
for t in npm npx; do
cat > "$TD/bin/$t" <<STUB
#!/bin/bash
echo "$t \$*" >> "$TD/calls"
echo "stub output from $t"
[[ "\$*" == *lint* && -f "$TD/lint.fail" ]] && exit 1
exit \$(cat "$TD/rc" 2>/dev/null || echo 0)
STUB
chmod +x "$TD/bin/$t"
done
PATHX="PATH=$TD/bin:$PATH"
C=$(bash_payload "git commit -m change")
go() { : > "$TD/calls"; run $H "${1:-$C}" "$PATHX" "${@:2}"; }
setrc() { echo "$1" > "$TD/rc"; }
ran() { grep -q "$1" "$TD/calls" 2>/dev/null; }
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1"; fi; }

go "$(bash_payload "git status")";        expect "non-commit ignored" 0
setrc 1
go "$(bash_payload "git commit -m 'WIP stuff'")"; expect "WIP bypasses" 0
go "$(bash_payload "git commit -m '[skip-verify] x'")"; expect "skip-verify bypasses" 0
go "$(bash_payload "git commit -m x --amend")"; expect "amend bypasses" 0
go "$C" DONE_GATE_SKIP=1;                 expect "DONE_GATE_SKIP bypasses" 0
expect_has "skip is announced" "$ERR" "DONE_GATE_SKIP"
go;                                       expect "no package or tsconfig passes" 0

# ci:local bundle
echo '{"scripts":{"ci:local":"echo hi"}}' > package.json
setrc 1; go;                              expect "failing ci:local blocks" 2
expect_has "names the bundle" "$ERR" "(ci:local) failed"
expect_has "tail of output shown" "$ERR" "stub output from npm"
check "ci:local was invoked" 'ran "run ci:local"'
check "no receipt after failure" '[[ ! -e .omc/state/done-receipt ]]'
setrc 0; go;                              expect "passing ci:local passes" 0
check "receipt written on pass" '[[ -s .omc/state/done-receipt ]]'
rm package.json .omc/state/done-receipt

# tsc fallback
echo '{}' > tsconfig.json
setrc 1; go;                              expect "failing tsc blocks" 2
expect_has "names tsc bundle" "$ERR" "(tsc) failed"
check "plain tsc --noEmit used" 'ran "tsc --noEmit"'
echo '{"references":[]}' > tsconfig.json
go
check "project references use tsc -b" 'ran "tsc -b"'
echo '{}' > tsconfig.json
echo '{"scripts":{"lint":"echo l"}}' > package.json
setrc 0; go;                              expect "tsc and lint pass" 0
check "lint script runs after tsc" 'ran "run lint"'
touch "$TD/lint.fail"
go;                                       expect "failing lint blocks" 2
expect_has "names tsc+lint bundle" "$ERR" "(tsc+lint) failed"
finish
