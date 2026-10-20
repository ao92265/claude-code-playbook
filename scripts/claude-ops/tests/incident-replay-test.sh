#!/bin/bash
# Tests for incident-replay.py with a fake claude, so no usage is spent.
# Run: bash ~/.claude/scripts/tests/incident-replay-test.sh
set -u
RUNNER=~/.claude/scripts/incident-replay.py
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0

# Fake claude: a judge call prints $FAKE_VERDICT, a review call prints a review.
# FAKE_MODE=error makes every call fail, like an expired login or an outage.
cat > "$T/claude" <<'EOF'
#!/bin/bash
[ "${FAKE_MODE:-}" = "error" ] && { echo "API Error: 529 overloaded" >&2; exit 1; }
prompt="$(cat)"
case "$prompt" in
  *"JUDGE THIS REVIEW"*) echo "${FAKE_VERDICT:-CAUGHT}"; echo "reason: fake" ;;
  *) echo "Finding: something about the diff" ;;
esac
EOF
chmod +x "$T/claude"

# Own fixture cases, so adding a real case never breaks this test.
for c in a b c d e f g; do
  mkdir -p "$T/cases/$c"; echo "+bad line" > "$T/cases/$c/change.diff"; echo "the bug" > "$T/cases/$c/expect.txt"
done

run() { INCIDENT_CLAUDE_BIN="$T/claude" INCIDENT_HOME="$T/home" INCIDENT_CASES="${CASES_DIR:-$T/cases}" INCIDENT_NO_ALERT=1 \
        /opt/homebrew/bin/python3 "$RUNNER" "$@" >"$T/out" 2>&1; echo $?; }
check() { [ "$2" = "$3" ] && echo "ok   $1" || { echo "FAIL $1: expected $3, got $2"; cat "$T/out"; fail=1; }; }

# 1. First run, everything caught: exit 0 and a ledger line with 7 of 7.
rc=$(FAKE_VERDICT=CAUGHT run); check "first run all caught exits 0" "$rc" 0
n=$(/opt/homebrew/bin/python3 -c "import json;r=[json.loads(l) for l in open('$T/home/ledger.jsonl')];print(r[-1]['caught'],r[-1]['total'])")
check "ledger records 7 of 7" "$n" "7 7"

# 2. Reviewer errors on every case: incomplete, exit 3, NOT counted as misses.
rc=$(FAKE_MODE=error run); check "reviewer errors exit 3" "$rc" 3
e=$(/opt/homebrew/bin/python3 -c "import json;r=[json.loads(l) for l in open('$T/home/ledger.jsonl')];print(r[-1]['errors'],r[-1]['caught'])")
check "errors recorded as errors, not misses" "$e" "7 0"

# 3. An errored run is not a baseline: a MISSED run compares to run 1 (7), so it drops.
rc=$(FAKE_VERDICT=MISSED run); check "errored run skipped, score drop exits 1" "$rc" 1
grep -q "DROPPED 7 to 0" "$T/out"; check "drop is reported against run 1" "$?" 0

# 4. Same misses again: the bar is the week's best (7), not yesterday's drop. Still a drop.
rc=$(FAKE_VERDICT=MISSED run); check "a drop does not lower the bar" "$rc" 1

# 4b. Verdict wording: "Verdict: CAUGHT." counts as caught.
rc=$(FAKE_VERDICT="Verdict: CAUGHT." run); check "punctuated verdict is caught" "$rc" 0

# 5. A garbled judge answer is an error, never a pass.
rc=$(FAKE_VERDICT="maybe" run); check "garbled verdict exits 3" "$rc" 3

# 6. --case runs one case only.
rc=$(FAKE_VERDICT=CAUGHT run --case c); check "--case exits 0" "$rc" 0
n=$(/opt/homebrew/bin/python3 -c "import json;r=[json.loads(l) for l in open('$T/home/ledger.jsonl')];print(r[-1]['total'])")
check "--case runs 1 case" "$n" 1

# 7. A corrupt ledger line is skipped, not a crash.
echo '{"broken' >> "$T/home/ledger.jsonl"
rc=$(FAKE_VERDICT=CAUGHT run); check "corrupt ledger line is skipped" "$rc" 0

# 8. A case with no expect.txt is an errored case (exit 3), never a crash or a drop.
mkdir -p "$T/cases/h"; echo "+x" > "$T/cases/h/change.diff"
rc=$(FAKE_VERDICT=CAUGHT run); check "missing expect.txt exits 3" "$rc" 3

# 9. A crash exits 3, never 1 (1 means the score dropped).
rc=$(CASES_DIR="$T/no-such-dir" FAKE_VERDICT=CAUGHT run); check "crash exits 3" "$rc" 3
grep -q "FileNotFoundError" "$T/out"; check "crash path really ran" "$?" 0

exit $fail
