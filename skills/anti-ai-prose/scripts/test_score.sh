#!/usr/bin/env bash
# Each fixture must give the expected exit code. Prints PASS/FAIL per case.
d="$(cd "$(dirname "$0")/.." && pwd)"; bad=0
chk() { python3 "$d/scripts/score.py" "$d/fixtures/$1" >/dev/null; rc=$?
  if [ "$rc" = "$2" ]; then echo "PASS $1 (exit $rc)"; else echo "FAIL $1 exit $rc want $2"; bad=1; fi; }
chk pass-clean.txt 0
chk fail-all.txt 1
chk fail-unsourced-number.txt 1
chk pass-sourced-number.txt 0
chk pass-code-stripped.txt 0
chk fail-code-unstripped.txt 1
python3 "$d/scripts/score.py" --allow-proof "$d/fixtures/fail-unsourced-number.txt" >/dev/null; rc=$?
[ "$rc" = 0 ] && echo "PASS allow-proof (exit 0)" || { echo "FAIL allow-proof $rc"; bad=1; }
exit $bad
