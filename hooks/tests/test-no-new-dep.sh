#!/bin/bash
# Runs the existing hooks/test-no-new-dep.sh against the repo copy with a throwaway HOME,
# then checks the disable switch and the new-project case it does not cover.
source "$(dirname "$0")/lib.sh"
HOOK="$HOOKS_DIR/no-new-dep.sh" bash "$HOOKS_DIR/test-no-new-dep.sh" || fail=$((fail+1))

H=no-new-dep.sh
pj="$TD/package.json"; printf '{"dependencies": {"react": "^19.0.0"}}' > "$pj"
add() { jq -nc --arg f "$1" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"\"react\": \"^19.0.0\"",new_string:"\"react\": \"^19.0.0\", \"uuid\": \"^11.0.0\""}}'; }
run $H "$(add "$pj")";                              expect "new dep warns" 1
run $H "$(add "$pj")" NO_NEW_DEP_DISABLED=1;        expect "NO_NEW_DEP_DISABLED=1 silences" 0
run $H "$(add "$pj")" CLAUDE_SKIP_HOOKS=no-new-dep; expect "CLAUDE_SKIP_HOOKS silences" 0
run $H "$(add "$TD/missing/package.json")";         expect "package.json that does not exist yet is silent" 0
finish
