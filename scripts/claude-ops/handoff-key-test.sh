#!/usr/bin/env bash
# Collision tests for hooks/lib/handoff-key.sh.
#
# The first version of that file keyed on basename+slugified-branch alone. Both of the
# COLLIDE checks below failed against it — same-named repos in different paths, and
# "fix/foo" vs "fix-foo" in one repo. Keep these tests next to any change to the key.
set -uo pipefail
. "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/lib/handoff-key.sh"

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

mkrepo() { # mkrepo <path> <branch>
  mkdir -p "$1" && git -C "$1" init -q 2>/dev/null
  git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m x 2>/dev/null
  git -C "$1" checkout -q -B "$2" 2>/dev/null
}

check() { # check <label> <expect: same|diff> <a> <b>
  if [ "$2" = diff ] && [ "$3" != "$4" ]; then pass=$((pass+1)); echo "  PASS $1"; return; fi
  if [ "$2" = same ] && [ "$3" = "$4" ]; then pass=$((pass+1)); echo "  PASS $1"; return; fi
  fail=$((fail+1)); echo "  FAIL $1"; echo "        a=$3"; echo "        b=$4"
}

echo "=== distinctness ==="
mkrepo "$TMP/one/Scheduler" main
mkrepo "$TMP/two/Scheduler" main
check "same repo name, different paths" diff \
  "$(handoff_key "$TMP/one/Scheduler")" "$(handoff_key "$TMP/two/Scheduler")"

mkrepo "$TMP/slash" "fix/foo"
A=$(handoff_key "$TMP/slash")
git -C "$TMP/slash" checkout -q -B "fix-foo"
check "branch fix/foo vs fix-foo" diff "$A" "$(handoff_key "$TMP/slash")"

mkrepo "$TMP/sep--x" main
mkrepo "$TMP/sep" "-x--main"
check "separator ambiguity in repo vs branch name" diff \
  "$(handoff_key "$TMP/sep--x")" "$(handoff_key "$TMP/sep")"

check "two named sessions, same non-repo cwd" diff \
  "$(handoff_key "$TMP" alpha)" "$(handoff_key "$TMP" beta)"

check "same name, different non-repo cwd" diff \
  "$(handoff_key "$TMP/a" shared)" "$(handoff_key "$TMP/b" shared)"

echo "=== stability ==="
check "same repo+branch twice" same \
  "$(handoff_key "$TMP/one/Scheduler")" "$(handoff_key "$TMP/one/Scheduler")"
check "subdir shares the repo root key" same \
  "$(handoff_key "$TMP/one/Scheduler")" "$(mkdir -p "$TMP/one/Scheduler/src" && handoff_key "$TMP/one/Scheduler/src")"
check "unnamed non-repo cwd keeps the legacy key" same \
  "$(handoff_key ~)" "$(handoff_legacy_key ~)"

echo "=== shape ==="
LONG=$(printf 'b%.0s' $(seq 1 300))
mkrepo "$TMP/long" main
git -C "$TMP/long" checkout -q -B "$LONG" 2>/dev/null
K=$(handoff_key "$TMP/long")
if [ "${#K}" -le 120 ] && [ -n "$K" ]; then pass=$((pass+1)); echo "  PASS 300-char branch -> ${#K}-char key"
else fail=$((fail+1)); echo "  FAIL long branch produced a ${#K}-char key"; fi
case "$K" in *[!A-Za-z0-9._-]*) fail=$((fail+1)); echo "  FAIL key has filesystem-unsafe chars: $K";; *) pass=$((pass+1)); echo "  PASS key is filesystem-safe";; esac

echo "=== fallback chain (orphan protection) ==="
FT="$TMP/fallback"; mkdir -p "$FT"
CUR=$(handoff_key "$TMP" ghost); INT=$(handoff_intermediate_key "$TMP" ghost); LEG=$(handoff_legacy_key "$TMP")
check "current and intermediate keys differ" diff "$CUR" "$INT"
printf 'i\n' > "$FT/$INT.md"
check "intermediate-only file is still found" same "$(handoff_newest "$FT" .md "$CUR" "$INT" "$LEG")" "$FT/$INT.md"
sleep 1; printf 'c\n' > "$FT/$CUR.md"
check "newer current file wins" same "$(handoff_newest "$FT" .md "$CUR" "$INT" "$LEG")" "$FT/$CUR.md"
sleep 1; printf 'i2\n' > "$FT/$INT.md"
check "newer intermediate file wins" same "$(handoff_newest "$FT" .md "$CUR" "$INT" "$LEG")" "$FT/$INT.md"
check "no candidate exists -> empty" same "$(handoff_newest "$FT" .md nothing-here)" ""

echo
echo "=== ownership (historical keys must not inject a sibling's handoff) ==="
OW="$TMP/own"; mkdir -p "$OW"
mkrepo "$TMP/ownA/Scheduler" main
mkrepo "$TMP/ownB/Scheduler" main
# A handoff written by repo B under the ambiguous intermediate key both repos share.
IK=$(handoff_intermediate_key "$TMP/ownB/Scheduler")
{ echo "## State"; echo "- Path: \`$TMP/ownB/Scheduler\`"; echo "- Branch: \`main\`"; } > "$OW/$IK.md"
if handoff_owns "$OW/$IK.md" "$TMP/ownA/Scheduler" ""; then
  fail=$((fail+1)); echo "  FAIL repo A claimed repo B's handoff under the shared key"
else pass=$((pass+1)); echo "  PASS repo A rejects repo B's handoff under the shared key"; fi
if handoff_owns "$OW/$IK.md" "$TMP/ownB/Scheduler" ""; then
  pass=$((pass+1)); echo "  PASS repo B still claims its own handoff"
else fail=$((fail+1)); echo "  FAIL repo B rejected its own handoff"; fi

# Same repo, different branch: must not be claimed.
git -C "$TMP/ownB/Scheduler" checkout -q -B other
if handoff_owns "$OW/$IK.md" "$TMP/ownB/Scheduler" ""; then
  fail=$((fail+1)); echo "  FAIL claimed a handoff recorded on a different branch"
else pass=$((pass+1)); echo "  PASS branch mismatch rejected"; fi

# Non-repo: named vs unnamed sharing the legacy cwd key.
{ echo "## State"; echo "- Path: \`$OW\`"; } > "$OW/unnamed.md"
if handoff_owns "$OW/unnamed.md" "$OW" alpha; then
  fail=$((fail+1)); echo "  FAIL named session claimed an unnamed session's handoff"
else pass=$((pass+1)); echo "  PASS named session rejects the unnamed handoff"; fi
if handoff_owns "$OW/unnamed.md" "$OW" ""; then
  pass=$((pass+1)); echo "  PASS unnamed session claims its own handoff"
else fail=$((fail+1)); echo "  FAIL unnamed session rejected its own handoff"; fi
{ echo "## State"; echo "- Path: \`$OW\`"; echo "- Session: alpha"; } > "$OW/named.md"
if handoff_owns "$OW/named.md" "$OW" beta; then
  fail=$((fail+1)); echo "  FAIL session beta claimed session alpha's handoff"
else pass=$((pass+1)); echo "  PASS cross-name rejected"; fi
if handoff_owns "$OW/named.md" "$OW" alpha; then
  pass=$((pass+1)); echo "  PASS alpha claims its own handoff"
else fail=$((fail+1)); echo "  FAIL alpha rejected its own handoff"; fi
if handoff_owns "$OW/nonexistent.md" "$OW" ""; then
  fail=$((fail+1)); echo "  FAIL claimed a file that does not exist"
else pass=$((pass+1)); echo "  PASS missing file rejected"; fi

echo
echo "=== headerless files are never claimable (sibling inference was unsound) ==="
CP="$TMP/compact"; mkdir -p "$CP"
printf '## Pre-compaction snapshot old\n' > "$CP/legacykey.compact.md"
if handoff_owns "$CP/legacykey.compact.md" "$CP" ""; then
  fail=$((fail+1)); echo "  FAIL headerless compact claimed with no sibling"
else pass=$((pass+1)); echo "  PASS headerless compact refused (no sibling)"; fi
# A sibling live handoff must NOT confer ownership: under an ambiguous key the sibling only
# identifies the most recent writer, which need not be whoever wrote the compact file.
{ echo "## State"; echo "- Path: \`$CP\`"; } > "$CP/legacykey.md"
if handoff_owns "$CP/legacykey.compact.md" "$CP" ""; then
  fail=$((fail+1)); echo "  FAIL sibling conferred ownership on a headerless compact"
else pass=$((pass+1)); echo "  PASS sibling does NOT confer ownership"; fi
printf 'no header\n' > "$CP/plain.md"
if handoff_owns "$CP/plain.md" "$CP" ""; then
  fail=$((fail+1)); echo "  FAIL headerless live handoff claimed"
else pass=$((pass+1)); echo "  PASS headerless live handoff refused"; fi
{ echo "## State"; echo "- Path: \`$CP\`"; echo "- Session: alpha"; } > "$CP/hdr.compact.md"
if handoff_owns "$CP/hdr.compact.md" "$CP" alpha; then
  pass=$((pass+1)); echo "  PASS headered compact claimed by its owner"
else fail=$((fail+1)); echo "  FAIL headered compact rejected its owner"; fi
if handoff_owns "$CP/hdr.compact.md" "$CP" beta; then
  fail=$((fail+1)); echo "  FAIL headered compact leaked to another session"
else pass=$((pass+1)); echo "  PASS headered compact refused to another session"; fi

echo "=== sessionstart temp-file handling ==="
SS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/sessionstart-handoff.sh"
if grep -q 'UNPROVEN_FILE=""' "$SS"; then
  pass=$((pass+1)); echo "  PASS mktemp failure falls back to empty, not /dev/null"
else fail=$((fail+1)); echo "  FAIL mktemp fallback is not empty — a trap could rm the fallback path"; fi
# Since the _emit refactor (JSON payload buffering) cleanup lives inside _emit, which is
# the single EXIT trap. The safety properties are unchanged, just relocated: removal still
# uses `rm -f --` (no option injection from the path) and is guarded so an empty variable
# can never become `rm -f /dev/null` or `rm -f` with a surprise argument.
if grep -qE 'rm -f -- "\$UNPROVEN_FILE"' "$SS"; then
  pass=$((pass+1)); echo "  PASS cleanup uses rm -f -- (no option injection from the path)"
else fail=$((fail+1)); echo "  FAIL cleanup is not using rm -f -- on UNPROVEN_FILE"; fi
if grep -qE '\[ -n "\$UNPROVEN_FILE" \] && .*rm -f -- "\$UNPROVEN_FILE"' "$SS"; then
  pass=$((pass+1)); echo "  PASS removal guarded on a non-empty path"
else fail=$((fail+1)); echo "  FAIL UNPROVEN_FILE removal is unguarded"; fi
# End to end: an unwritable TMPDIR must not break the hook and must not touch /dev/null.
# Type, mode and device only: ls -l includes an mtime that ticks on every write, so a
# minute boundary mid-test failed it.
_dn_before=$(stat -f '%HT %Sp %Z' /dev/null 2>/dev/null)
TMPDIR=/nonexistent-dir-xyz sh -c 'echo "{\"cwd\":\"$HOME\",\"source\":\"startup\"}" | bash "$0"' "$SS" >/dev/null 2>&1
_dn_after=$(stat -f '%HT %Sp %Z' /dev/null 2>/dev/null)
check "unwritable TMPDIR leaves /dev/null intact" same "$_dn_before" "$_dn_after"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
echo "=== ALL PASS ==="
