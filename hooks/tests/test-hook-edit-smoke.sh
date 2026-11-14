#!/bin/bash
# hook-edit-smoke.sh: editing a hook script under ~/.claude/hooks runs the smoke test; a failing smoke test exits 2 with the FAIL lines.
source "$(dirname "$0")/lib.sh"
H=hook-edit-smoke.sh
mkdir -p "$HOME/.claude/hooks" "$HOME/.claude/scripts"
SMOKE="$HOME/.claude/scripts/hooks-smoke-test.sh"
ed() { run $H "$(file_payload Edit "$1")" "${@:2}"; }
HOOK="$HOME/.claude/hooks/some-hook.sh"

ed "$HOOK";                               expect "no smoke script passes" 0
printf '#!/bin/bash\necho "FAIL some-hook case 3"\necho "noise line"\nexit 1\n' > "$SMOKE"
ed "$HOOK";                               expect "failing smoke blocks with 2" 2
expect_has "failing line surfaced" "$ERR" "FAIL some-hook case 3"
expect_lacks "noise filtered out" "$ERR" "noise line"
expect_has "names the edited file" "$ERR" "$HOOK"
ed "$HOOK" CLAUDE_SKIP_HOOKS=hook-edit-smoke; expect "skip env honoured" 0
ed "$HOME/.claude/hooks/notes.md";        expect "non-sh file ignored" 0
ed "$TD/elsewhere/x.sh";                  expect "path outside hooks dir ignored" 0
printf '#!/bin/bash\nexit 0\n' > "$SMOKE"
ed "$HOOK";                               expect "passing smoke passes" 0
finish
