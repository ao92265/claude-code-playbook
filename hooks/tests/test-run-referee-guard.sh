#!/bin/bash
# run-referee-guard.sh: a session with a referee sentinel is blocked (2) on every tool except writing its own reboot handoff.
source "$(dirname "$0")/lib.sh"
H=run-referee-guard.sh
SD="$HOME/.claude/run-referee/sentinels"
T="/proj/abc-123.jsonl"
guard() { run $H "$1" "${@:2}"; }
pay() { local ti="${3:-}"; [ -n "$ti" ] || ti="{}"; jq -nc --arg t "$1" --arg tp "${2:-$T}" --argjson ti "$ti" '{tool_name:$t,transcript_path:$tp,tool_input:$ti}'; }

guard "$(pay Bash)";                         expect "no sentinel dir allows" 0
mkdir -p "$SD"
guard "$(pay Bash)";                         expect "no sentinel for this session allows" 0
printf '{"verdict":"pause","reason":"over four hours","transcript_path":"%s"}' "$T" > "$SD/abc-123"
guard "$(pay Bash '' '{"command":"ls"}')";   expect "sentinel blocks a tool" 2
expect_has "message carries the reason" "$ERR" "over four hours"
guard "$(pay Read)";                         expect "sentinel blocks every tool" 2
guard "$(pay Bash /other/abc-123.jsonl)";    expect "same uuid in another project dir not blocked" 0
guard "$(pay Write '' "{\"file_path\":\"$HOME/.claude/reboots/reboot-1.md\"}")"; expect "writing the reboot handoff is allowed" 0
guard "$(pay Write '' "{\"file_path\":\"$HOME/.claude/reboots/../x.md\"}")";     expect "dotdot escape from reboot dir blocked" 2
guard "$(pay Write '' '{"file_path":"/proj/src.ts"}')";                          expect "other writes blocked" 2
guard "$(pay Write '' "{\"file_path\":\"$TD/rb/r.md\"}")" OMC_REBOOT_DIR="$TD/rb"; expect "reboot dir override honoured" 0
guard "$(pay Skill '' '{"skill":"keep"}')";  expect "keep skill allowed" 0
guard "$(pay Skill '' '{"skill":"deploy"}')"; expect "other skills blocked" 2
guard "$(pay Bash '' '{"command":"~/.claude/scripts/keep.sh on"}')"; expect "bare keep.sh allowed" 0
guard "$(pay Bash '' '{"command":"~/.claude/scripts/keep.sh on && ls"}')"; expect "chained keep.sh blocked" 2
printf '{"verdict":"kill","reason":"loop"}' > "$SD/abc-123"
guard "$(pay Bash)";                         expect "legacy sentinel without path blocks by uuid" 2
guard '{"tool_name":"Bash"}';                expect "no transcript path allows" 0
finish
