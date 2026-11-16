#!/bin/bash
# plan-gate.sh: editing source with no recent plan/spec warns (1); a plan file silences it.
source "$(dirname "$0")/lib.sh"
H=plan-gate.sh
W="$TD/w"; mkdir -p "$W"; cd "$W" || exit 1
git init -q .
ed() { run $H "$(file_payload Edit "$1")" "${@:2}"; }

ed "$W/a.ts";                          expect "no plan warns" 1
expect_has "warning says no plan" "$ERR" "no plan/spec found"
ed "$W/a.ts" PLAN_GATE_DISABLED=1;     expect "disable env honoured" 0
ed "$W/README.md";                     expect "markdown skipped" 0
ed "$W/a.txt";                         expect "non-source skipped" 0
ed "$W/node_modules/x/a.js";           expect "node_modules skipped" 0
touch PLAN.md;                         ed "$W/a.ts"; expect "PLAN.md present passes" 0
rm PLAN.md
mkdir -p tasks; touch tasks/t.md;      ed "$W/a.ts"; expect "tasks/*.md passes" 0
rm tasks/t.md
mkdir -p .omc/plans; touch .omc/plans/p.md; ed "$W/a.ts"; expect ".omc/plans passes" 0
rm .omc/plans/p.md
touch -t 202001010000 SPEC.md;         ed "$W/a.ts"; expect "stale SPEC.md still warns" 1
ed "$W/a.ts" PLAN_GATE_WINDOW_DAYS=99999; expect "window override accepts old spec" 0
finish
