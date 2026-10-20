#!/bin/bash
# Tests for explainer-gate.py. Run: bash ~/.claude/scripts/tests/explainer-gate-test.sh
set -u
HOOK=~/.claude/hooks/explainer-gate.py
T="$(mktemp -d "$HOME/.explainer-gate-test.XXXXXX")"  # not under /var/folders, which the hook skips
trap 'rm -rf "$T"' EXIT
fail=0
mkdir -p "$T/repo/src/billing" "$T/repo/src/auth" "$T/state"
echo 'def charge(): pass' > "$T/repo/src/billing/charge.py"
echo 'def total(): pass'  > "$T/repo/src/billing/total.py"
echo 'def login(): pass'  > "$T/repo/src/auth/login.py"
echo '# notes'            > "$T/repo/src/billing/README.md"
TR="$T/transcript.jsonl"; : > "$TR"

# JSON goes through printf '%s' so bash never touches its escapes.
payload() { # file [agent_id] [sid]
  /opt/homebrew/bin/python3 -c 'import json,sys
d={"session_id":sys.argv[3],"transcript_path":sys.argv[4],"tool_name":"Edit","tool_input":{"file_path":sys.argv[1]}}
if sys.argv[2]: d["agent_id"]=sys.argv[2]
print(json.dumps(d))' "$1" "${2:-}" "${3:-s1}" "$TR"; }
run() { printf '%s' "$(payload "$@")" | EXPLAINER_STATE="$T/state" /opt/homebrew/bin/python3 "$HOOK" >/dev/null 2>"$T/err"; echo $?; }
say() { # append an assistant text turn to the transcript
  /opt/homebrew/bin/python3 -c 'import json,sys
print(json.dumps({"type":"assistant","message":{"content":[{"type":"text","text":sys.argv[1]}]}}))' "$1" >> "$TR"; }
check() { [ "$2" = "$3" ] && echo "ok   $1" || { echo "FAIL $1: expected $3, got $2"; cat "$T/err"; fail=1; }; }

say "Explainer: billing does X. (said BEFORE the block, must not count)"
rc=$(run "$T/repo/src/billing/charge.py"); check "first edit in a folder is blocked" "$rc" 2
grep -q "billing" "$T/err"; check "block names the folder" "$?" 0
say "Explainer gate blocked that edit, retrying now."
rc=$(run "$T/repo/src/billing/charge.py"); check "narrating the block is not an explainer" "$rc" 2
rc=$(run "$T/repo/src/billing/charge.py"); check "third try fails open" "$rc" 0

# Fresh session: an explainer written after the block lets the edit through.
rc=$(run "$T/repo/src/auth/login.py" "" s2); check "s2 first edit blocked" "$rc" 2
say "Explainer: auth/login.py checks the password against the hash and sets the session cookie; the router calls it."
rc=$(run "$T/repo/src/auth/login.py" "" s2); check "explainer after block lets it through" "$rc" 0
rc=$(run "$T/repo/src/auth/login.py" "" s2); check "folder stays explained" "$rc" 0

rc=$(run "$T/repo/src/billing/total.py" "" s3); check "other session is not pre-explained" "$rc" 2
rc=$(run "$T/repo/src/billing/new_file.py" "" s4); check "new file is skipped" "$rc" 0
rc=$(run "$T/repo/src/billing/README.md" "" s4); check "markdown is skipped" "$rc" 0
rc=$(run "$T/repo/src/billing/charge.py" "agent-123" s5); check "subagent is skipped" "$rc" 0
rc=$(printf '%s' 'not json' | EXPLAINER_STATE="$T/state" /opt/homebrew/bin/python3 "$HOOK" 2>/dev/null; echo $?)
check "bad payload fails open" "$rc" 0

exit $fail
