#!/usr/bin/env bash
# matcha-offload-gate - PreToolUse on Agent. When the subscription window is
# nearly spent, cheap mechanical subagent work stops being free and starts
# being the thing that ends the session early. This blocks those spawns and
# points them at Matcha, which bills Harris instead.
#
# Deliberately narrow: only fires when the window is genuinely nearly gone, and
# only on cheap-tier agents. Judgment work on the top tier still runs here.
# Fails open on any error. Bypass with MATCHA_OFFLOAD_OK=1.
payload="$(cat 2>/dev/null)"
[[ -n "$payload" ]] || exit 0
[[ "${MATCHA_OFFLOAD_OK:-0}" == "1" ]] && exit 0
[[ -n "$CLAUDE_SKIP_HOOKS" && "$CLAUDE_SKIP_HOOKS" == *matcha* ]] && exit 0

model="$(printf '%s' "$payload" | jq -r '.tool_input.model // ""' 2>/dev/null)"
[[ "$model" == "haiku" || "$model" == "sonnet" ]] || exit 0

verdict="$(python3 - <<'PY' 2>/dev/null
import json, os, time
p = os.path.expanduser("~/.claude/usage-history.jsonl")
try:
    if time.time() - os.path.getmtime(p) > 1800:
        raise SystemExit
    with open(p, "rb") as fh:
        fh.seek(max(0, os.path.getsize(p) - 4000))
        last = fh.read().decode("utf-8", "replace").strip().splitlines()[-1]
    d = json.loads(last)
    five = d.get("five_hour", {}).get("used_percentage", 0)
    week = d.get("seven_day", {}).get("used_percentage", 0)
except Exception:
    raise SystemExit
if week >= 92 or five >= 90:
    print("%d %d" % (five, week))
PY
)"
[[ -n "$verdict" ]] || exit 0
five="${verdict%% *}"; week="${verdict##* }"

cat >&2 <<EOF
matcha offload gate: subscription at ${five}% of the 5 hour window and ${week}% of the week.
A ${model} subagent is exactly the work that should not be spending what is left.

Send this task to Matcha instead (billed to Harris, not the subscription):
  ~/.claude/scripts/matcha-run.sh --tier $( [[ "$model" == haiku ]] && echo fast || echo standard ) "<the task, with all the context the delegate needs>"
Add --write only if the task genuinely has to edit files.

Keep judgment, orchestration and anything needing this conversation's context here.
If this really must run locally, MATCHA_OFFLOAD_OK=1 must be exported before the session started.
EOF
exit 2
