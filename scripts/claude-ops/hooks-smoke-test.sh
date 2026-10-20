#!/usr/bin/env bash
# Smoke test all hooks — syntax + fast-path exit.
# Run after editing any hook: bash ~/.claude/scripts/hooks-smoke-test.sh

set -u
HOOKS_DIR="$HOME/.claude/hooks"
FAIL=0

echo "=== syntax check ==="
for h in "$HOOKS_DIR"/*.sh; do
  # voice-queue.sh links into a voice front end, which is macOS-only (say, afplay, Keychain).
  # Off the Mac the link dangles, so skip it rather than fail every Linux run.
  if [ "$(basename "$h")" = "voice-queue.sh" ] && [ "$(uname)" != "Darwin" ]; then
    echo "SKIP $(basename "$h") (macOS-only)"
    continue
  fi
  if bash -n "$h" 2>/dev/null; then
    echo "OK  $(basename "$h")"
  else
    echo "FAIL $(basename "$h")"
    bash -n "$h"
    FAIL=$((FAIL+1))
  fi
done

PYCHECK='import ast,sys; ast.parse(open(sys.argv[1]).read())'
for h in "$HOOKS_DIR"/*.py; do
  if python3 -c "$PYCHECK" "$h" 2>/dev/null; then
    echo "OK  $(basename "$h")"
  else
    echo "FAIL $(basename "$h")"
    python3 -c "$PYCHECK" "$h"
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "=== fast-path exit (non-matching command) ==="
NONMATCH='{"tool_input":{"command":"echo hello"}}'

for h in codex-prepush-review.sh auto-simplify.sh firewall.sh pre-commit-verify.sh tdd-gate.sh; do
  if [ -f "$HOOKS_DIR/$h" ]; then
    START=$(date +%s)
    echo "$NONMATCH" | "$HOOKS_DIR/$h" &>/dev/null
    CODE=$?
    END=$(date +%s)
    DUR=$((END-START))
    if [ "$DUR" -lt 3 ] && [ "$CODE" -ne 1 ]; then
      echo "OK  $h (exit $CODE, ${DUR}s)"
    else
      echo "SLOW/BAD $h (exit $CODE, ${DUR}s)"
      FAIL=$((FAIL+1))
    fi
  fi
done

echo ""
echo "=== require-agent-model fixtures ==="
RAM="$HOOKS_DIR/require-agent-model.sh"
if [ -f "$RAM" ]; then
  # 1) plain model-less Agent spawn (no definition-pinned model) must block (exit 2)
  echo '{"tool_name":"Agent","tool_input":{"prompt":"x","subagent_type":"general-purpose"},"session_id":"smoke"}' \
    | env -u CLAUDE_CODE_SUBAGENT_MODEL -u REQUIRE_AGENT_MODEL_DISABLED "$RAM" >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 2 ]; then
    echo "OK  require-agent-model blocks model-less plain spawn (exit 2)"
  else
    echo "FAIL require-agent-model: model-less plain spawn exit $CODE (want 2)"
    FAIL=$((FAIL+1))
  fi
  # 2) explicit model must pass (exit 0)
  echo '{"tool_name":"Agent","tool_input":{"prompt":"x","model":"sonnet","subagent_type":"general-purpose"},"session_id":"smoke"}' \
    | env -u CLAUDE_CODE_SUBAGENT_MODEL -u REQUIRE_AGENT_MODEL_DISABLED "$RAM" >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 0 ]; then
    echo "OK  require-agent-model passes explicit model (exit 0)"
  else
    echo "FAIL require-agent-model: explicit-model spawn exit $CODE (want 0)"
    FAIL=$((FAIL+1))
  fi
  # 3) model-less spawn of a type whose definition pins model: must pass (exit 0)
  if grep -qE '^model:[[:space:]]*[^[:space:]]' "$HOME/.claude/agents/executor.md" 2>/dev/null; then
    echo '{"tool_name":"Task","tool_input":{"prompt":"x","subagent_type":"oh-my-claudecode:executor"},"session_id":"smoke"}' \
      | env -u CLAUDE_CODE_SUBAGENT_MODEL -u REQUIRE_AGENT_MODEL_DISABLED "$RAM" >/dev/null 2>&1
    CODE=$?
    if [ "$CODE" -eq 0 ]; then
      echo "OK  require-agent-model passes definition-pinned type (exit 0)"
    else
      echo "FAIL require-agent-model: definition-pinned type exit $CODE (want 0)"
      FAIL=$((FAIL+1))
    fi
  else
    echo "SKIP definition-pinned fixture (no model: in ~/.claude/agents/executor.md)"
  fi
fi

echo ""
echo "=== reboot-stamp + handoff-key fixtures ==="
RS="$HOOKS_DIR/reboot-stamp.sh"
KEYLIB="$HOOKS_DIR/lib/handoff-key.sh"
if [ -f "$RS" ] && [ -f "$KEYLIB" ] && command -v jq >/dev/null 2>&1; then
  RT=$(mktemp -d)
  REPO="$RT/repo"
  mkdir -p "$REPO" "$RT/reboots"
  git -C "$REPO" init -q -b main 2>/dev/null || git -C "$REPO" init -q
  # 1) headerless reboot gets stamped with Path + Session from the hook input
  FIX="$RT/reboots/reboot-0000-00-00-smoke.md"
  printf '# Smoke reboot\n\nbody line\n' > "$FIX"
  printf '{"tool_input":{"file_path":"%s"},"cwd":"%s","session_name":"smoke-alpha"}' "$FIX" "$REPO" \
    | OMC_REBOOT_DIR="$RT/reboots" OMC_REBOOT_STATE_DIR="$RT/state" "$RS" >/dev/null 2>&1
  if grep -q '^- Path: `' "$FIX" && grep -q '^- Session: smoke-alpha$' "$FIX"; then
    echo "OK  reboot-stamp inserts identity block"
  else
    echo "FAIL reboot-stamp did not stamp: $(head -5 "$FIX" | tr '\n' '|')"; FAIL=$((FAIL+1))
  fi
  # 2) already-stamped file must pass through untouched (even with a different name)
  BEFORE=$(cat "$FIX")
  printf '{"tool_input":{"file_path":"%s"},"cwd":"%s","session_name":"smoke-beta"}' "$FIX" "$REPO" \
    | OMC_REBOOT_DIR="$RT/reboots" OMC_REBOOT_STATE_DIR="$RT/state" "$RS" >/dev/null 2>&1
  if [ "$BEFORE" = "$(cat "$FIX")" ]; then
    echo "OK  reboot-stamp idempotent on stamped file"
  else
    echo "FAIL reboot-stamp restamped an already-stamped file"; FAIL=$((FAIL+1))
  fi

  # shellcheck source=/dev/null
  . "$KEYLIB"
  # 3) unnamed repo key must be byte-identical to the shared (pre-2026-08-12) key
  K_UN=$(handoff_key "$REPO" "")
  K_SH=$(handoff_repo_shared_key "$REPO")
  K_A=$(handoff_key "$REPO" "alpha")
  K_B=$(handoff_key "$REPO" "beta")
  if [ -n "$K_UN" ] && [ "$K_UN" = "$K_SH" ]; then
    echo "OK  unnamed repo key unchanged (matches shared key)"
  else
    echo "FAIL unnamed repo key drifted: '$K_UN' vs '$K_SH'"; FAIL=$((FAIL+1))
  fi
  # 4) named sessions in one repo+branch must not share a key
  if [ "$K_A" != "$K_B" ] && [ "$K_A" != "$K_UN" ]; then
    echo "OK  named repo keys are per-session"
  else
    echo "FAIL named repo keys collide: A='$K_A' B='$K_B' UN='$K_UN'"; FAIL=$((FAIL+1))
  fi

  # 5) ownership: same name claims, sibling name rejected, pre-change file stays claimable
  BR=$(git -C "$REPO" branch --show-current 2>/dev/null)
  OWNED="$RT/owned.md"
  printf -- '- Path: `%s`\n- Branch: `%s`\n- Session: alpha\n' "$REPO" "$BR" > "$OWNED"
  if handoff_owns "$OWNED" "$REPO" "alpha"; then
    echo "OK  owns: same session name claims"
  else
    echo "FAIL owns: same name rejected"; FAIL=$((FAIL+1))
  fi
  if handoff_owns "$OWNED" "$REPO" "beta"; then
    echo "FAIL owns: sibling session name claimed the file"; FAIL=$((FAIL+1))
  else
    echo "OK  owns: mismatched session name rejected"
  fi
  NONAME="$RT/noname.md"
  printf -- '- Path: `%s`\n- Branch: `%s`\n' "$REPO" "$BR" > "$NONAME"
  if handoff_owns "$NONAME" "$REPO" "alpha"; then
    echo "OK  owns: pre-change file (no Session line) still claimable by named session"
  else
    echo "FAIL owns: pre-change file orphaned"; FAIL=$((FAIL+1))
  fi
  rm -r "$RT"
else
  echo "SKIP reboot-stamp/handoff-key fixtures (hook, lib, or jq missing)"
fi

echo ""
echo "=== run-referee-guard fixtures ==="
RG="$HOOKS_DIR/run-referee-guard.sh"
if [ -f "$RG" ] && command -v jq >/dev/null 2>&1; then
  SUID="smoke-referee-fixture"
  SDIR="$HOME/.claude/run-referee/sentinels"
  mkdir -p "$SDIR"
  TP="/tmp/smoke-referee/$SUID.jsonl"
  printf '{"verdict":"pause","reason":"smoke fixture","transcript_path":"%s"}' "$TP" > "$SDIR/$SUID"
  # 1) sentinel present: ordinary tool blocked
  printf '{"transcript_path":"%s","tool_name":"Bash","tool_input":{"command":"echo hi"}}' "$TP" | "$RG" >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 2 ]; then
    echo "OK  referee blocks ordinary tool under sentinel (exit 2)"
  else
    echo "FAIL referee ordinary tool exit $CODE (want 2)"; FAIL=$((FAIL+1))
  fi
  # 2) escape hatch: Write into reboots dir allowed
  printf '{"transcript_path":"%s","tool_name":"Write","tool_input":{"file_path":"%s/.claude/reboots/reboot-smoke.md"}}' "$TP" "$HOME" | "$RG" >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 0 ]; then
    echo "OK  referee allows reboot handoff Write (exit 0)"
  else
    echo "FAIL referee reboot Write exit $CODE (want 0)"; FAIL=$((FAIL+1))
  fi
  # 3) traversal out of the reboots dir stays blocked
  printf '{"transcript_path":"%s","tool_name":"Write","tool_input":{"file_path":"%s/.claude/reboots/../hooks/evil.md"}}' "$TP" "$HOME" | "$RG" >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 2 ]; then
    echo "OK  referee blocks traversal path (exit 2)"
  else
    echo "FAIL referee traversal exit $CODE (want 2)"; FAIL=$((FAIL+1))
  fi
  # 4) no sentinel: fast allow
  rm -f "$SDIR/$SUID"
  printf '{"transcript_path":"%s","tool_name":"Bash","tool_input":{"command":"echo hi"}}' "$TP" | "$RG" >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 0 ]; then
    echo "OK  referee allows when no sentinel (exit 0)"
  else
    echo "FAIL referee no-sentinel exit $CODE (want 0)"; FAIL=$((FAIL+1))
  fi
else
  echo "SKIP run-referee-guard fixtures (hook or jq missing)"
fi

echo ""
echo "=== branch-guard shared-tree fixtures ==="
BG="$HOOKS_DIR/branch-guard.sh"
REPO=$(git -C "$HOME/.claude" rev-parse --show-toplevel 2>/dev/null \
  || find "$HOME/Repos" -maxdepth 2 -name .git -type d 2>/dev/null | head -1 | xargs -I{} dirname {})
if [ -f "$BG" ] && [ -n "${REPO:-}" ] && [ -d "$REPO" ] && command -v jq >/dev/null 2>&1; then
  BGH="/tmp/smoke-branchguard-$$"
  mkdir -p "$BGH/.claude/sessions" "$BGH/.claude/state"
  sleep 20 & BGPEER=$!
  disown "$BGPEER" 2>/dev/null || true   # keep the kill below off the transcript
  printf '{"pid": %s, "sessionId": "peer-sid", "name": "smoke-peer", "cwd": "%s"}\n' "$BGPEER" "$REPO" \
    > "$BGH/.claude/sessions/peer.json"
  PAYLOAD=$(printf '{"tool_input":{"file_path":"%s/README.md"},"session_id":"smoke-mine"}' "$REPO")
  # 1) live peer in the same checkout: blocked
  printf '%s' "$PAYLOAD" | HOME="$BGH" "$BG" >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 2 ]; then
    echo "OK  branch-guard blocks shared-tree collision (exit 2)"
  else
    echo "FAIL branch-guard collision exit $CODE (want 2)"; FAIL=$((FAIL+1))
  fi
  # 2) the peer's own session must not block itself
  printf '{"tool_input":{"file_path":"%s/README.md"},"session_id":"peer-sid"}' "$REPO" \
    | HOME="$BGH" "$BG" >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 0 ]; then
    echo "OK  branch-guard does not block the peer's own session (exit 0)"
  else
    echo "FAIL branch-guard self-block exit $CODE (want 0)"; FAIL=$((FAIL+1))
  fi
  # 3) documented override still lets work through
  printf '%s' "$PAYLOAD" | HOME="$BGH" OMC_SKIP_HOOKS=branch-guard "$BG" >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 0 ]; then
    echo "OK  branch-guard override bypasses the block (exit 0)"
  else
    echo "FAIL branch-guard override exit $CODE (want 0)"; FAIL=$((FAIL+1))
  fi
  # ── push mode (19 Aug 2026) ──────────────────────────────────────────────────
  # The edit-time check above missed the collision that actually happened: both
  # sessions were correctly in their own worktrees, the second was DETACHED so it
  # matched no branch, and both pushed to one branch. The push refspec is the first
  # place the true target is stated, so these pin that path.
  BGBRANCH=$(git -C "$REPO" symbolic-ref --short -q HEAD 2>/dev/null || echo main)
  # 5) a push aimed at a branch a live peer OWNS FROM ANOTHER WORKTREE: blocked.
  #    The peer gets a real second worktree, detached, declaring the branch in its
  #    session file. That is the incident this check was added for and what the
  #    comment above always claimed; until 19 Aug 2026 the fixture instead put the
  #    peer in the pusher's OWN checkout, which passes for a different reason and
  #    hid the false positive case 5b now pins.
  BGWT="/tmp/smoke-branchguard-peer-wt-$$"
  if git -C "$REPO" worktree add --detach "$BGWT" >/dev/null 2>&1; then
    printf '{"pid": %s, "sessionId": "peer-sid", "name": "smoke-peer", "cwd": "%s", "branch": "%s"}\n' \
      "$BGPEER" "$BGWT" "$BGBRANCH" > "$BGH/.claude/sessions/peer.json"
    printf '{"tool_input":{"command":"git push origin HEAD:%s"},"session_id":"smoke-mine"}' "$BGBRANCH" \
      | (cd "$REPO" && HOME="$BGH" "$BG") >/dev/null 2>&1
    CODE=$?
    if [ "$CODE" -eq 2 ]; then
      echo "OK  branch-guard blocks a push to a branch a peer owns from another worktree (exit 2)"
    else
      echo "FAIL branch-guard push-collision exit $CODE (want 2)"; FAIL=$((FAIL+1))
    fi
  else
    echo "FAIL branch-guard push-collision could not create the peer worktree"; FAIL=$((FAIL+1))
  fi

  # 5b) a peer merely SITTING in the pusher's own checkout must NOT block the push.
  #     Regression, 19 Aug 2026: three sessions had that one checkout open, two of
  #     them read-only, and every push from it was blocked and escalated. The peer's
  #     branch is read from its cwd, so a peer in my tree reports whatever branch I
  #     put my tree on: it cannot be on a different one, and that is not evidence it
  #     is working on it. Same-tree collisions stay the edit-time half's job, pinned
  #     by case 1 above.
  printf '{"pid": %s, "sessionId": "peer-sid", "name": "smoke-peer", "cwd": "%s"}\n' "$BGPEER" "$REPO" \
    > "$BGH/.claude/sessions/peer.json"
  printf '{"tool_input":{"command":"git push origin HEAD:%s"},"session_id":"smoke-mine"}' "$BGBRANCH" \
    | (cd "$REPO" && HOME="$BGH" "$BG") >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 0 ]; then
    echo "OK  branch-guard lets a push through past a same-checkout peer (exit 0)"
  else
    echo "FAIL branch-guard same-tree push exit $CODE (want 0)"; FAIL=$((FAIL+1))
  fi
  # 6) the same words QUOTED are not an invocation and must not block. A substring
  #    match reds every doc example and this suite's own fixtures (measured).
  printf '{"tool_input":{"command":"echo \\"remember to git push origin HEAD:%s\\""},"session_id":"smoke-mine"}' "$BGBRANCH" \
    | (cd "$REPO" && HOME="$BGH" "$BG") >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 0 ]; then
    echo "OK  branch-guard ignores the push words when quoted (exit 0)"
  else
    echo "FAIL branch-guard quoted-push exit $CODE (want 0)"; FAIL=$((FAIL+1))
  fi
  # 7) a push aimed somewhere nobody is: allowed
  printf '{"tool_input":{"command":"git push origin HEAD:feat/smoke-branch-nobody-owns"},"session_id":"smoke-mine"}' \
    | (cd "$REPO" && HOME="$BGH" "$BG") >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 0 ]; then
    echo "OK  branch-guard allows a push to an unowned branch (exit 0)"
  else
    echo "FAIL branch-guard unowned-push exit $CODE (want 0)"; FAIL=$((FAIL+1))
  fi

  # 4) no live peer: advisory only, never blocks
  rm -f "$BGH/.claude/sessions/peer.json"
  printf '%s' "$PAYLOAD" | HOME="$BGH" "$BG" >/dev/null 2>&1
  CODE=$?
  if [ "$CODE" -eq 0 ]; then
    echo "OK  branch-guard stays advisory with no peer (exit 0)"
  else
    echo "FAIL branch-guard no-peer exit $CODE (want 0)"; FAIL=$((FAIL+1))
  fi
  kill "$BGPEER" 2>/dev/null
  [ -n "${BGWT:-}" ] && git -C "$REPO" worktree remove --force "$BGWT" >/dev/null 2>&1
  rm -rf "$BGH" 2>/dev/null
else
  echo "SKIP branch-guard fixtures (hook, git repo or jq missing)"
fi

echo ""
echo "=== search-first-nudge fixtures ==="
SF="$HOOKS_DIR/search-first-nudge.sh"
if [ -f "$SF" ] && command -v jq >/dev/null 2>&1; then
  SFSID="smoke-search-$$"
  rm -f "$HOME/.claude/state/searchnudge-$SFSID"
  OUT=$(printf '{"tool_input":{"command":"grep -r foo src/"},"session_id":"%s"}' "$SFSID" | "$SF" 2>&1)
  if printf '%s' "$OUT" | grep -q "search-first"; then
    echo "OK  search-first fires on a bare search"
  else
    echo "FAIL search-first silent on a bare search"; FAIL=$((FAIL+1))
  fi
  OUT=$(printf '{"tool_input":{"command":"rg again"},"session_id":"%s"}' "$SFSID" | "$SF" 2>&1)
  if [ -z "$OUT" ]; then
    echo "OK  search-first quiet on the second lookup"
  else
    echo "FAIL search-first nagged twice"; FAIL=$((FAIL+1))
  fi
  OUT=$(printf '{"tool_input":{"command":"git log --oneline | grep fix"},"session_id":"smoke-pipe-%s"}' "$$" | "$SF" 2>&1)
  if [ -z "$OUT" ]; then
    echo "OK  search-first ignores a grep filtering a real command"
  else
    echo "FAIL search-first fired on a piped grep"; FAIL=$((FAIL+1))
  fi
  rm -f "$HOME/.claude/state/searchnudge-$SFSID" "$HOME/.claude/state/searchnudge-smoke-pipe-$$"
else
  echo "SKIP search-first-nudge fixtures (hook or jq missing)"
fi

echo ""
echo "=== chrome-ref-first fixtures ==="
CR="$HOOKS_DIR/chrome-ref-first.sh"
if [ -f "$CR" ] && command -v jq >/dev/null 2>&1; then
  CRSID="smoke-chromeref-$$"
  rm -f "$HOME/.claude/state/chromeref-$CRSID"*
  OUT=$(printf '{"tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"left_click","coordinate":[1,2]},"session_id":"%s"}' "$CRSID" | "$CR" 2>&1)
  if printf '%s' "$OUT" | grep -q "chrome-ref-first"; then
    echo "OK  chrome-ref-first fires on a coordinate click"
  else
    echo "FAIL chrome-ref-first silent on a coordinate click"; FAIL=$((FAIL+1))
  fi
  OUT=$(printf '{"tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"left_click","ref":"ref_1"},"session_id":"%s-b"}' "$CRSID" | "$CR" 2>&1)
  if [ -z "$OUT" ]; then
    echo "OK  chrome-ref-first quiet on a ref click"
  else
    echo "FAIL chrome-ref-first fired on a ref click"; FAIL=$((FAIL+1))
  fi
  rm -f "$HOME/.claude/state/chromeref-$CRSID"*
else
  echo "SKIP chrome-ref-first fixtures (hook or jq missing)"
fi

echo ""
echo "=== sessionstart unproven-pointer fixtures ==="
# Regression guard for the 2026-08-19 fix. The "may be this session's" list must contain
# ONLY files whose ownership is genuinely unprovable (no identity header). A file whose
# header names another session's path is proven NOT ours, and listing it reads as "this
# might be your work" about someone else's plan.
#
# The 2026-08-19 bug: `grep -v` exits 1 when it selects no lines, which here is the
# CORRECT outcome (every candidate had a header, so nothing is unprovable). A `||`
# fallback treated that as failure and printed the whole candidate list instead.
#
# Case B is the guard that reproduces it: with NO headerless file the complement is
# legitimately empty. Case A (a headerless file present) passes even on the broken code,
# because a non-empty complement never reaches the fallback -- it is kept as an invariant
# check, not as the regression test. A fixture that passes on the bug proves nothing.
SSH_HOOK="$HOME/.claude/hooks/sessionstart-handoff.sh"
if [ -f "$SSH_HOOK" ]; then
  ss_run() { # ss_run <dir> -> hook output for an unnamed session outside a repo
    # env -u: a pane that restore-sessions.sh opened carries RESTORE_HANDOFF for life, and
    # a smoke test run from it would exercise the restore branch instead of the scan.
    printf '{"cwd":"%s","source":"startup"}' "$1/work" \
      | env -u RESTORE_HANDOFF OMC_REBOOT_DIR="$1/reboots" OMC_REBOOT_STATE_DIR="$1/state" \
        CLAUDE_CONFIG_DIR="$1/cfg" bash "$SSH_HOOK" 2>&1
  }
  ss_setup() {
    mkdir -p "$1/reboots" "$1/cfg/hooks" "$1/cfg/handoffs" "$1/work"
    ln -sfn "$HOME/.claude/hooks/lib" "$1/cfg/hooks/lib"
  }
  ss_clean() {
    rm -f "$1"/reboots/*.md "$1/cfg/hooks/lib" 2>/dev/null
    find "$1" -depth -type d -exec rmdir {} + 2>/dev/null || true
  }

  # A. two proven-other reboots alongside one genuinely ambiguous file
  SSA=$(mktemp -d 2>/dev/null || echo "/tmp/ss-smoke-a-$$")
  ss_setup "$SSA"
  printf '# old style\nno identity header here\n' > "$SSA/reboots/headerless.md"
  printf '# reboot\n- Path: `/home/nobody/Repos/alpha`\n- Session: alpha-sess\n' > "$SSA/reboots/other-alpha.md"
  printf '# reboot\n- Path: `/home/nobody/Repos/beta`\n- Session: beta-sess\n' > "$SSA/reboots/other-beta.md"
  OUT=$(ss_run "$SSA")
  case "$OUT" in
    *headerless.md*) echo "OK  sessionstart lists the unprovable headerless reboot" ;;
    *) echo "FAIL sessionstart dropped the headerless reboot"; FAIL=$((FAIL+1)) ;;
  esac
  case "$OUT" in
    *other-alpha.md*|*other-beta.md*)
      echo "FAIL sessionstart offered another session's proven reboot"; FAIL=$((FAIL+1)) ;;
    *) echo "OK  sessionstart hides reboots proven to be other sessions'" ;;
  esac
  ss_clean "$SSA"

  # B. nothing ambiguous at all -> the pointer list must not appear
  SSB2=$(mktemp -d 2>/dev/null || echo "/tmp/ss-smoke-b-$$")
  ss_setup "$SSB2"
  printf '# reboot\n- Path: `/home/nobody/Repos/alpha`\n- Session: alpha-sess\n' > "$SSB2/reboots/only-other.md"
  OUT=$(ss_run "$SSB2")
  case "$OUT" in
    *only-other.md*|*"MAY be this session"*)
      echo "FAIL sessionstart showed a pointer list with nothing unprovable"; FAIL=$((FAIL+1)) ;;
    *) echo "OK  sessionstart stays quiet when nothing is unprovable" ;;
  esac
  ss_clean "$SSB2"

  # C. RESTORE_HANDOFF must apply to the restore launch ONLY (source=startup). It is an
  # env var on the claude process, so it outlives the first session: every later /clear
  # in that pane re-injected the morning's restore file and exited before the pid claim
  # ticket, so a /reboot -> /clear in a restored pane resumed the WRONG session.
  # Bitten 2026-09-23 (one pane got another project's handoff). On source=clear the var is
  # ignored and the ticket wins.
  SSC=$(mktemp -d 2>/dev/null || echo "/tmp/ss-smoke-c-$$")
  ss_setup "$SSC"
  mkdir -p "$SSC/state/reboot-pending" "$SSC/cfg/sessions"
  printf '{"sessionId":"smoke-c","cwd":"%s","name":"smoke-c","nameSource":"user"}' "$SSC/work" > "$SSC/cfg/sessions/$$.json"
  printf '# stale restore\n- Path: `%s`\n- Session: yesterday-sess\nSTALE_RESTORE_BODY\n' "$SSC/work" > "$SSC/cfg/handoffs/restore.md"
  printf '# reboot\n- Path: `%s`\n- Session: smoke-c\nTICKET_REBOOT_BODY\n' "$SSC/work" > "$SSC/reboots/reboot-2026-09-23-1550-smoke-c.md"
  printf '%s\n' "$SSC/reboots/reboot-2026-09-23-1550-smoke-c.md" > "$SSC/state/reboot-pending/$$"
  OUT=$(printf '{"cwd":"%s","source":"clear","session_id":"smoke-c"}' "$SSC/work" \
    | RESTORE_HANDOFF="$SSC/cfg/handoffs/restore.md" OMC_REBOOT_DIR="$SSC/reboots" \
      OMC_REBOOT_STATE_DIR="$SSC/state" CLAUDE_CONFIG_DIR="$SSC/cfg" bash "$SSH_HOOK" 2>&1)
  case "$OUT" in
    *STALE_RESTORE_BODY*) echo "FAIL sessionstart replayed RESTORE_HANDOFF on /clear"; FAIL=$((FAIL+1)) ;;
    *) echo "OK  sessionstart ignores RESTORE_HANDOFF on /clear" ;;
  esac
  case "$OUT" in
    *TICKET_REBOOT_BODY*) echo "OK  sessionstart honours the pid claim ticket on /clear in a restored pane" ;;
    *) echo "FAIL sessionstart skipped the pid claim ticket behind RESTORE_HANDOFF"; FAIL=$((FAIL+1)) ;;
  esac
  OUT=$(printf '{"cwd":"%s","source":"startup"}' "$SSC/work" \
    | RESTORE_HANDOFF="$SSC/cfg/handoffs/restore.md" OMC_REBOOT_DIR="$SSC/reboots" \
      OMC_REBOOT_STATE_DIR="$SSC/state" CLAUDE_CONFIG_DIR="$SSC/cfg" bash "$SSH_HOOK" 2>&1)
  case "$OUT" in
    *STALE_RESTORE_BODY*) echo "OK  sessionstart still honours RESTORE_HANDOFF on the restore launch" ;;
    *) echo "FAIL sessionstart dropped RESTORE_HANDOFF on startup"; FAIL=$((FAIL+1)) ;;
  esac
  rm -f "$SSC/cfg/sessions/$$.json" "$SSC/state/reboot-pending/$$" "$SSC/cfg/handoffs/restore.md" "$SSC/reboots/"*.md
  ss_clean "$SSC"
else
  echo "SKIP sessionstart unproven-pointer fixtures (hook missing)"
fi

echo ""
echo "=== paste-guard fixtures ==="
PG="$HOOKS_DIR/paste-guard.py"
if [ -f "$PG" ]; then
  PGHOME=$(mktemp -d 2>/dev/null || echo "/tmp/pg-smoke-$$")
  mkdir -p "$PGHOME/.claude/state/paste-guard"
  PG_OFF="$PGHOME/.claude/state/paste-guard/off"
  # split literal: a whole dummy key in this file would trip secret-scanner.py
  PG_KEY="AKIA""IOSFODNN7EXAMPLE"
  PG_WRAP='import json,sys; print(json.dumps({"hook_event_name":"UserPromptSubmit","prompt":sys.stdin.read()}))'

  # empty stdout = prompt allowed through; JSON with a decision = blocked.
  # PATH=/nonexistent so pbcopy is unreachable and the real clipboard is safe.
  pg_run() {
    printf '%s' "$1" | python3 -c "$PG_WRAP" \
      | env -u PASTE_GUARD_DISABLED HOME="$PGHOME" PATH=/nonexistent /usr/bin/python3 "$PG" 2>/dev/null
  }
  pg_expect() { # $1 label, $2 block|pass, $3 prompt
    OUT=$(pg_run "$3")
    if [ "$2" = "block" ]; then
      case "$OUT" in
        *'"decision"'*) echo "OK  paste-guard blocks $1" ;;
        *) echo "FAIL paste-guard let $1 through"; FAIL=$((FAIL+1)) ;;
      esac
    else
      if [ -z "$OUT" ]; then
        echo "OK  paste-guard allows $1"
      else
        echo "FAIL paste-guard blocked $1"; FAIL=$((FAIL+1))
      fi
    fi
  }
  pg_sanitize() { printf '%s' "$1" | env -u PASTE_GUARD_DISABLED HOME="$PGHOME" python3 "$PG" --sanitize 2>/dev/null; }

  pg_expect "a dummy AWS key"                  block "creds: $PG_KEY here"
  pg_expect "an allowlisted work email"        pass  "mail user@example.com"
  pg_expect "a plus-tagged allowed email"      pass  "cc jane+tag@acme.example"
  pg_expect "a subdomain of an allowed domain" pass  "svc@mail.acme.example"
  pg_expect "an outside email"                 block "mail stranger@example.org"
  pg_expect "a lookalike domain"               block "billing@notacme.example"
  pg_expect "a !!raw prefixed prompt"          pass  "!!raw creds: $PG_KEY"

  # the off-switch has to be a FILE. An env var exported inside a session never
  # reaches the hook, which is what made the original switch a no-op.
  touch "$PG_OFF"
  pg_expect "everything while switched off"    pass  "creds: $PG_KEY here"
  rm -f "$PG_OFF"
  pg_expect "a key once switched back on"      block "creds: $PG_KEY here"

  # the clipboard sanitizer layer must honour the same switch
  case "$(pg_sanitize 'ping stranger@example.org')" in
    *REDACTED:Email*) echo "OK  paste-guard --sanitize redacts an outside email" ;;
    *) echo "FAIL paste-guard --sanitize left an outside email"; FAIL=$((FAIL+1)) ;;
  esac
  case "$(pg_sanitize 'ping user@example.com')" in
    *user@example.com*) echo "OK  paste-guard --sanitize keeps an allowlisted email" ;;
    *) echo "FAIL paste-guard --sanitize redacted an allowlisted email"; FAIL=$((FAIL+1)) ;;
  esac
  touch "$PG_OFF"
  case "$(pg_sanitize 'ping stranger@example.org')" in
    *stranger@example.org*) echo "OK  paste-guard --sanitize honours the off-switch" ;;
    *) echo "FAIL paste-guard --sanitize still redacting while switched off"; FAIL=$((FAIL+1)) ;;
  esac

  rm -f "$PG_OFF" "$PGHOME/.claude/logs/paste-guard.jsonl"
  rmdir "$PGHOME/.claude/state/paste-guard" "$PGHOME/.claude/state" \
        "$PGHOME/.claude/logs" "$PGHOME/.claude" "$PGHOME" 2>/dev/null
else
  echo "SKIP paste-guard fixtures (hook missing)"
fi

echo ""
echo "=== documented bypass switches (must be human-only) ==="
# Each hook advertises an env-var escape hatch. A hook only ever sees the
# environment `claude` was launched with, so these fixtures set the variable in
# the hook's OWN environment, which is exactly what a pre-launch export gives.
# The inline-prefix case is the regression guard: it must STAY blocked, because
# a switch the agent can write into a command is a switch the agent can flip.

# firewall: a destructive command it is meant to stop. Fed as JSON text only,
# never executed. Path is fake.
FW_CMD='rm -rf /tmp/hooks-smoke-does-not-exist'
# stderr silenced: a hook that exits before reading stdin gives this a SIGPIPE
fw_payload() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1" 2>/dev/null; }

if [ -f "$HOOKS_DIR/firewall.sh" ]; then
  fw_payload "$FW_CMD" | env -u CLAUDE_SKIP_HOOKS -u OMC_SKIP_HOOKS "$HOOKS_DIR/firewall.sh" >/dev/null 2>&1
  [ $? -eq 2 ] && echo "OK  firewall blocks a destructive command" \
    || { echo "FAIL firewall did not block a destructive command"; FAIL=$((FAIL+1)); }

  # the measured 2026-08-19 behaviour: an inline prefix cannot reach the hook
  fw_payload "CLAUDE_SKIP_HOOKS=firewall $FW_CMD" | env -u CLAUDE_SKIP_HOOKS -u OMC_SKIP_HOOKS "$HOOKS_DIR/firewall.sh" >/dev/null 2>&1
  [ $? -eq 2 ] && echo "OK  firewall ignores an inline CLAUDE_SKIP_HOOKS prefix (agent cannot self-authorise)" \
    || { echo "FAIL firewall honoured an inline prefix: the agent can now bypass it"; FAIL=$((FAIL+1)); }

  fw_payload "$FW_CMD" | env CLAUDE_SKIP_HOOKS=firewall "$HOOKS_DIR/firewall.sh" >/dev/null 2>&1
  [ $? -eq 0 ] && echo "OK  firewall honours a pre-launch CLAUDE_SKIP_HOOKS export" \
    || { echo "FAIL firewall ignored its own documented switch"; FAIL=$((FAIL+1)); }
else
  echo "SKIP firewall switch fixtures (hook missing)"
fi

# firewall: tmux kill-server. 14 Oct 2026 a bare kill-server inside a real pane
# killed all 11 sessions ($TMUX beats TMUX_TMPDIR). Private servers must still pass.
# FW_HOOK override lets a mutated copy prove these fixtures can go red.
FW_HOOK="${FW_HOOK:-$HOOKS_DIR/firewall.sh}"
if [ -f "$FW_HOOK" ]; then
  while IFS='|' read -r want cmd; do
    fw_payload "$cmd" | env -u CLAUDE_SKIP_HOOKS -u OMC_SKIP_HOOKS bash "$FW_HOOK" >/dev/null 2>&1
    got=$?
    [ "$got" -eq "$want" ] && echo "OK  firewall tmux: exit $want for '$cmd'" \
      || { echo "FAIL firewall tmux: '$cmd' gave $got, want $want"; FAIL=$((FAIL+1)); }
  done <<'EOF'
2|tmux kill-server
2|TMUX_TMPDIR=/tmp/hooks-smoke tmux kill-server
2|pkill tmux
0|tmux -L hooks-smoke kill-server
0|unset TMUX; TMUX_TMPDIR=/tmp/hooks-smoke tmux kill-server
EOF
else
  echo "SKIP firewall tmux fixtures (hook missing)"
fi

# require-agent-model: the block path already has fixtures above; this asserts
# the documented emergency switch still works.
if [ -f "$HOOKS_DIR/require-agent-model.sh" ]; then
  echo '{"tool_name":"Agent","tool_input":{"prompt":"x","subagent_type":"general-purpose"},"session_id":"smoke"}' \
    | env -u CLAUDE_CODE_SUBAGENT_MODEL REQUIRE_AGENT_MODEL_DISABLED=1 "$HOOKS_DIR/require-agent-model.sh" >/dev/null 2>&1
  [ $? -eq 0 ] && echo "OK  require-agent-model honours its documented switch" \
    || { echo "FAIL require-agent-model ignored REQUIRE_AGENT_MODEL_DISABLED"; FAIL=$((FAIL+1)); }
fi

# secret-scanner: path must avoid its own fixture allowlist (/fixtures/, examples/,
# anything containing "secret-scanner") or it exits 0 before scanning.
if [ -f "$HOOKS_DIR/secret-scanner.py" ]; then
  SS_KEY="AKIA""IOSFODNN7EXAMPLE"
  ss_payload() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","hook_event_name":"PreToolUse","tool_input":{"file_path":"/tmp/smoke-target.py","content":"KEY = \""+sys.argv[1]+"\""}}))' "$SS_KEY" 2>/dev/null; }
  ss_payload | env -u SECRET_SCANNER_DISABLED python3 "$HOOKS_DIR/secret-scanner.py" >/dev/null 2>&1
  [ $? -ne 0 ] && echo "OK  secret-scanner blocks a key in a Write" \
    || { echo "FAIL secret-scanner let a key through"; FAIL=$((FAIL+1)); }
  ss_payload | env SECRET_SCANNER_DISABLED=1 python3 "$HOOKS_DIR/secret-scanner.py" >/dev/null 2>&1
  [ $? -eq 0 ] && echo "OK  secret-scanner honours its documented switch" \
    || { echo "FAIL secret-scanner ignored SECRET_SCANNER_DISABLED"; FAIL=$((FAIL+1)); }
fi

# plan-gate: warns (exit 1) on a source edit with no plan in the tree, so run it
# from an empty temp dir or the repo's own plans/ would satisfy it.
if [ -f "$HOOKS_DIR/plan-gate.sh" ]; then
  PGDIR=$(mktemp -d 2>/dev/null || echo "/tmp/plangate-smoke-$$")
  PG_PAYLOAD='{"tool_input":{"file_path":"/tmp/smoke-target.ts"}}'
  ( cd "$PGDIR" && echo "$PG_PAYLOAD" | env -u PLAN_GATE_DISABLED "$HOOKS_DIR/plan-gate.sh" >/dev/null 2>&1 )
  [ $? -eq 1 ] && echo "OK  plan-gate warns when no plan is nearby" \
    || { echo "FAIL plan-gate did not warn"; FAIL=$((FAIL+1)); }
  ( cd "$PGDIR" && echo "$PG_PAYLOAD" | env PLAN_GATE_DISABLED=1 "$HOOKS_DIR/plan-gate.sh" >/dev/null 2>&1 )
  [ $? -eq 0 ] && echo "OK  plan-gate honours its documented switch" \
    || { echo "FAIL plan-gate ignored PLAN_GATE_DISABLED"; FAIL=$((FAIL+1)); }
  rmdir "$PGDIR" 2>/dev/null
fi

# review gate (inside verify-gate.sh): source files edited with nothing having
# reviewed them AFTER the edits must block the stop once. Ordering is by
# transcript timestamp, so every fixture line carries an explicit one: the first
# argument to each helper is the second-of-minute the entry happened at, which
# is what most of these cases are actually testing. Every pass case is paired
# with a mutation that must block, so deleting a rule fails a test rather than
# quietly turning every case green.
if [ -f "$HOOKS_DIR/verify-gate.sh" ]; then
  RGDIR=$(mktemp -d 2>/dev/null || echo "/tmp/reviewgate-smoke-$$")
  RG_SESSION="smoke-review-gate-$$"
  RG_STATE="$HOME/.claude/state/review-gate"
  rm -f "$RG_STATE/$RG_SESSION"* 2>/dev/null

  rg_edit() { printf '{"type":"assistant","timestamp":"2026-08-20T00:00:%02d.000Z","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"%s","old_string":"a","new_string":"b"}}]}}\n' "$1" "$2"; }
  rg_agent() { printf '{"type":"assistant","timestamp":"2026-08-20T00:00:%02d.000Z","message":{"content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"%s","prompt":"go"}}]}}\n' "$1" "$2"; }
  rg_sub() { printf '{"type":"assistant","timestamp":"2026-08-20T00:00:%02d.000Z","message":{"content":[{"type":"tool_use","name":"%s","input":{"file_path":"%s"}}]}}\n' "$1" "$2" "$3"; }
  rg_bash() { printf '{"type":"assistant","timestamp":"2026-08-20T00:00:%02d.000Z","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"%s"}}]}}\n' "$1" "$2"; }
  rg_text() { printf '{"type":"%s","timestamp":"2026-08-20T00:00:%02d.000Z","message":{"content":"%s"}}\n' "$2" "$1" "$3"; }
  # $1 transcript, $2 session, $3 stop_hook_active (default false)
  rg_run() { echo "{\"session_id\":\"$2\",\"transcript_path\":\"$1\",\"stop_hook_active\":${3:-false}}" | ( cd "$RGDIR" && "$HOOKS_DIR/verify-gate.sh" 2>"$RGDIR/err.txt" >/dev/null ); }

  # 1. two source files, nothing reviewed them: blocks, and says why
  { rg_edit 1 "/repo/alpha.ts"; rg_edit 2 "/repo/beta.ts"; } > "$RGDIR/two.jsonl"
  rg_run "$RGDIR/two.jsonl" "$RG_SESSION"
  if [ $? -eq 2 ] && grep -q "REVIEW GATE" "$RGDIR/err.txt"; then
    echo "OK  review-gate blocks 2 unreviewed source edits and names itself"
  else
    echo "FAIL review-gate did not block 2 unreviewed source edits"; FAIL=$((FAIL+1))
  fi

  # 2. same session again: blocked once already, must yield, and the marker is why
  rg_run "$RGDIR/two.jsonl" "$RG_SESSION"
  if [ $? -eq 0 ] && [ -f "$RG_STATE/$RG_SESSION.blocked" ]; then
    echo "OK  review-gate yields after one block, marker recorded"
  else
    echo "FAIL review-gate loop guard or its marker is missing"; FAIL=$((FAIL+1))
  fi

  # 3. reviewer AFTER the edits passes; the same reviewer BEFORE them must not.
  #    This is the pair that catches an early /done spawning verifier and
  #    exempting every edit made afterwards.
  { rg_edit 1 "/repo/alpha.ts"; rg_edit 2 "/repo/beta.ts"; rg_agent 3 "code-reviewer"; } > "$RGDIR/after.jsonl"
  rg_run "$RGDIR/after.jsonl" "$RG_SESSION-after"
  [ $? -eq 0 ] && echo "OK  review-gate passes when the reviewer ran after the edits" \
    || { echo "FAIL review-gate blocked despite a reviewer after the edits"; FAIL=$((FAIL+1)); }
  { rg_agent 1 "verifier"; rg_edit 2 "/repo/alpha.ts"; rg_edit 3 "/repo/beta.ts"; } > "$RGDIR/before.jsonl"
  rg_run "$RGDIR/before.jsonl" "$RG_SESSION-before"
  [ $? -eq 2 ] && echo "OK  review-gate rejects a reviewer that ran before the edits" \
    || { echo "FAIL review-gate accepted a stale reviewer from earlier in the session"; FAIL=$((FAIL+1)); }

  # 4. delegated work: no main-chain edits at all, the edits live in the
  #    subagent's own transcript, which has its own line numbering. Without this
  #    the gate is inert on exactly the multi-file work that gets delegated.
  mkdir -p "$RGDIR/sub/subagents"
  rg_agent 1 "executor" > "$RGDIR/sub.jsonl"
  { rg_sub 2 Edit "/repo/gamma.ts"; rg_sub 3 Edit "/repo/delta.ts"; } > "$RGDIR/sub/subagents/agent-executor.jsonl"
  rg_run "$RGDIR/sub.jsonl" "$RG_SESSION-sub"
  [ $? -eq 2 ] && echo "OK  review-gate sees edits made by a subagent" \
    || { echo "FAIL review-gate is blind to subagent edits"; FAIL=$((FAIL+1)); }

  # 4a. delegated edits are ordered by WHEN they happened. Executor edits at
  #     :02-:03, review at :10, read-only Explore at :20. The Explore must not
  #     re-arm the gate on work the review already covered.
  mkdir -p "$RGDIR/attr/subagents"
  { rg_agent 1 "executor"; rg_agent 10 "code-reviewer"; rg_agent 20 "Explore"; } > "$RGDIR/attr.jsonl"
  { rg_sub 2 Edit "/repo/pinned1.ts"; rg_sub 3 Edit "/repo/pinned2.ts"; } > "$RGDIR/attr/subagents/agent-executor.jsonl"
  rg_sub 21 Read "/repo/pinned1.ts" > "$RGDIR/attr/subagents/agent-explore.jsonl"
  rg_run "$RGDIR/attr.jsonl" "$RG_SESSION-attr"
  [ $? -eq 0 ] && echo "OK  review-gate does not re-arm on a read-only agent after review" \
    || { echo "FAIL review-gate treated a read-only Explore as fresh unreviewed work"; FAIL=$((FAIL+1)); }
  # control: identical shape, but the delegated edits land AFTER the review
  mkdir -p "$RGDIR/attr2/subagents"
  { rg_agent 1 "code-reviewer"; rg_agent 10 "executor"; rg_agent 20 "Explore"; } > "$RGDIR/attr2.jsonl"
  { rg_sub 11 Edit "/repo/pinned3.ts"; rg_sub 12 Edit "/repo/pinned4.ts"; } > "$RGDIR/attr2/subagents/agent-executor.jsonl"
  rg_run "$RGDIR/attr2.jsonl" "$RG_SESSION-attr2"
  [ $? -eq 2 ] && echo "OK  review-gate still blocks delegated edits made after the review" \
    || { echo "FAIL review-gate missed delegated edits made after the review"; FAIL=$((FAIL+1)); }

  # 4g. the ordinary shape: review, then delegate the fix ON THOSE SAME FILES.
  #     The file set does not grow, so anything keyed on "new paths appeared"
  #     misses it and the stale review still counts. Must block.
  mkdir -p "$RGDIR/redo/subagents"
  { rg_edit 1 "/repo/c.ts"; rg_edit 2 "/repo/d.ts"; rg_agent 30 "code-reviewer"; rg_agent 40 "executor"; } > "$RGDIR/redo.jsonl"
  { rg_sub 50 Edit "/repo/c.ts"; rg_sub 51 Edit "/repo/d.ts"; } > "$RGDIR/redo/subagents/agent-executor.jsonl"
  rg_run "$RGDIR/redo.jsonl" "$RG_SESSION-redo"
  [ $? -eq 2 ] && echo "OK  review-gate blocks a re-edit of already-known files after review" \
    || { echo "FAIL review-gate missed a post-review re-edit of the same files"; FAIL=$((FAIL+1)); }

  # 4h. a reviewer writing its own probe script is not unreviewed work
  mkdir -p "$RGDIR/probe/subagents"
  { rg_edit 1 "/repo/e.ts"; rg_edit 2 "/repo/f.ts"; rg_agent 30 "code-reviewer"; } > "$RGDIR/probe.jsonl"
  rg_sub 35 Write "/tmp/probe.py" > "$RGDIR/probe/subagents/agent-code-reviewer.jsonl"
  rg_run "$RGDIR/probe.jsonl" "$RG_SESSION-probe"
  [ $? -eq 0 ] && echo "OK  review-gate ignores a reviewer's own scratch script" \
    || { echo "FAIL review-gate counted a reviewer probe script as fresh work"; FAIL=$((FAIL+1)); }

  # 4b. shell writes count: under bypass permissions most edits are Bash
  #     redirects and in-place seds, not Edit calls. Reads must not count.
  { rg_bash 1 "cat > /repo/eps.ts <<EOF"; rg_bash 2 "sed -i .bak s/a/b/ /repo/zeta.ts"; } > "$RGDIR/shell.jsonl"
  rg_run "$RGDIR/shell.jsonl" "$RG_SESSION-shell"
  [ $? -eq 2 ] && echo "OK  review-gate counts source files written from Bash" \
    || { echo "FAIL review-gate is blind to shell writes"; FAIL=$((FAIL+1)); }
  { rg_bash 1 "grep -n foo /repo/eps.ts"; rg_bash 2 "cat /repo/zeta.ts"; } > "$RGDIR/shellread.jsonl"
  rg_run "$RGDIR/shellread.jsonl" "$RG_SESSION-shellread"
  [ $? -eq 0 ] && echo "OK  review-gate does not count shell reads as edits" \
    || { echo "FAIL review-gate counted a grep or cat as an edit"; FAIL=$((FAIL+1)); }

  # 4c. path lookalikes, two per half of the filter, so dropping either half
  #     pushes the count to 2 and blocks. Absolute-with-metacharacter is caught
  #     only by the metacharacter check; bare relative only by the path check.
  { rg_bash 1 "printf x > /repo/%%s/a.ts"; rg_bash 2 "printf x > /repo/\$OUT/b.ts"; } > "$RGDIR/meta.jsonl"
  rg_run "$RGDIR/meta.jsonl" "$RG_SESSION-meta"
  [ $? -eq 0 ] && echo "OK  review-gate ignores templates and unexpanded variables" \
    || { echo "FAIL review-gate counted a printf template or an unexpanded variable"; FAIL=$((FAIL+1)); }
  { rg_bash 1 "echo x > rel/a.ts"; rg_bash 2 "echo x > rel/b.ts"; } > "$RGDIR/rel.jsonl"
  rg_run "$RGDIR/rel.jsonl" "$RG_SESSION-rel"
  [ $? -eq 0 ] && echo "OK  review-gate ignores a relative write with nothing to anchor it" \
    || { echo "FAIL review-gate guessed a directory for a bare relative path"; FAIL=$((FAIL+1)); }

  # 4d. the same relative writes DO count when the command says where they land,
  #     and the anchor is the LAST cd before the write, not the first one in the
  #     string. Both files here must be filed under /repo, not /elsewhere.
  { rg_bash 1 "cd /elsewhere && ls; cd /repo && cat > src/one.ts <<EOF"
    rg_bash 2 "cd /elsewhere && ls; cd /repo && cat > src/two.ts <<EOF"; } > "$RGDIR/anchored.jsonl"
  rg_run "$RGDIR/anchored.jsonl" "$RG_SESSION-anchored"
  if [ $? -eq 2 ] && grep -q "^/repo/src/one.ts$" "$RG_STATE/$RG_SESSION-anchored.blocked" 2>/dev/null \
     && ! grep -q "^/elsewhere/src" "$RG_STATE/$RG_SESSION-anchored.blocked" 2>/dev/null; then
    echo "OK  review-gate anchors a relative write to the cd that governs it"
  else
    echo "FAIL review-gate used the wrong cd for a relative write"; FAIL=$((FAIL+1))
  fi

  # 4d2. a relative write that comes BEFORE the cd has nothing governing it yet,
  #      so it is dropped. This pins the "cd must precede the write" half of the
  #      rule, which the case above cannot: there both cds precede the write.
  { rg_bash 1 "printf x > src/pre1.ts; cd /repo && ls"
    rg_bash 2 "printf x > src/pre2.ts; cd /repo && ls"; } > "$RGDIR/prewrite.jsonl"
  rg_run "$RGDIR/prewrite.jsonl" "$RG_SESSION-prewrite"
  [ $? -eq 0 ] && echo "OK  review-gate drops a relative write that precedes its cd" \
    || { echo "FAIL review-gate anchored a write to a cd that came after it"; FAIL=$((FAIL+1)); }

  # 4d3. a repo folder that happens to be called tmp is real work, not scratch
  { rg_edit 1 "/home/x/Repos/app/src/tmp/helper.ts"; rg_edit 2 "/home/x/Repos/app/tmp/build.ts"; } > "$RGDIR/repotmp.jsonl"
  rg_run "$RGDIR/repotmp.jsonl" "$RG_SESSION-repotmp"
  [ $? -eq 2 ] && echo "OK  review-gate counts a repo's own tmp folder as real work" \
    || { echo "FAIL review-gate skipped a repo path containing tmp"; FAIL=$((FAIL+1)); }

  # 4e. two prose arrows and two heredoc-quoted redirects, so dropping either
  #     rule alone pushes the count to 2 and blocks.
  { rg_bash 1 "echo 'moved /repo/a.py -> /repo/arrow1.ts' >> /repo/CHANGELOG.md"
    rg_bash 2 "echo 'moved /repo/b.py => /repo/arrow2.ts' >> /repo/CHANGELOG.md"; } > "$RGDIR/arrows.jsonl"
  rg_run "$RGDIR/arrows.jsonl" "$RG_SESSION-arrows"
  [ $? -eq 0 ] && echo "OK  review-gate reads an arrow in prose as prose" \
    || { echo "FAIL review-gate counted a prose arrow as a redirect"; FAIL=$((FAIL+1)); }
  { rg_bash 1 "cat > /repo/doc.md <<EOF\nbuild > /repo/here1.ts\nEOF"
    rg_bash 2 "cat > /repo/doc2.md <<EOF\nbuild > /repo/here2.ts\nEOF"; } > "$RGDIR/heredoc.jsonl"
  rg_run "$RGDIR/heredoc.jsonl" "$RG_SESSION-heredoc"
  [ $? -eq 0 ] && echo "OK  review-gate reads a heredoc body as data" \
    || { echo "FAIL review-gate counted a redirect quoted inside a heredoc"; FAIL=$((FAIL+1)); }

  # 4f. a write wrapped in a subshell still counts: the closing paren must not
  #     swallow the extension
  { rg_bash 1 "(cd /repo && printf x > src/paren1.ts)"
    rg_bash 2 "(cd /repo && printf x > src/paren2.ts)"; } > "$RGDIR/paren.jsonl"
  rg_run "$RGDIR/paren.jsonl" "$RG_SESSION-paren"
  [ $? -eq 2 ] && echo "OK  review-gate counts a write wrapped in a subshell" \
    || { echo "FAIL review-gate lost a write to a closing paren"; FAIL=$((FAIL+1)); }

  # 5. one file is under the bar
  rg_edit 1 "/repo/alpha.ts" > "$RGDIR/one.jsonl"
  rg_run "$RGDIR/one.jsonl" "$RG_SESSION-one"
  [ $? -eq 0 ] && echo "OK  review-gate ignores a single-file edit" \
    || { echo "FAIL review-gate fired on a single-file edit"; FAIL=$((FAIL+1)); }

  # 6. prose is not source
  { rg_edit 1 "$HOME/.claude/plans/x.md"; rg_edit 2 "/repo/notes.md"; } > "$RGDIR/prose.jsonl"
  rg_run "$RGDIR/prose.jsonl" "$RG_SESSION-prose"
  [ $? -eq 0 ] && echo "OK  review-gate ignores markdown-only sessions" \
    || { echo "FAIL review-gate fired on a markdown-only session"; FAIL=$((FAIL+1)); }

  # 7. a slash command in USER text counts as review; the same tag quoted back in
  #    assistant prose does not
  { rg_edit 1 "/repo/alpha.ts"; rg_edit 2 "/repo/beta.ts"; rg_text 3 user "<command-name>/code-review</command-name>"; } > "$RGDIR/usercmd.jsonl"
  rg_run "$RGDIR/usercmd.jsonl" "$RG_SESSION-usercmd"
  [ $? -eq 0 ] && echo "OK  review-gate accepts /code-review typed by the user" \
    || { echo "FAIL review-gate ignored a real /code-review run"; FAIL=$((FAIL+1)); }
  { rg_edit 1 "/repo/alpha.ts"; rg_edit 2 "/repo/beta.ts"; rg_text 3 assistant "<command-name>/code-review</command-name>"; } > "$RGDIR/fakecmd.jsonl"
  rg_run "$RGDIR/fakecmd.jsonl" "$RG_SESSION-fakecmd"
  [ $? -eq 2 ] && echo "OK  review-gate is not fooled by the command name in prose" \
    || { echo "FAIL review-gate accepted a mention of /code-review as a review"; FAIL=$((FAIL+1)); }

  # 8. fail-open paths, each paired with the same input minus the excuse
  rg_run "$RGDIR/two.jsonl" "$RG_SESSION-active" true
  [ $? -eq 0 ] && echo "OK  review-gate stands down when it already blocked this turn" \
    || { echo "FAIL review-gate re-blocked inside the same turn"; FAIL=$((FAIL+1)); }
  rg_run "$RGDIR/two.jsonl" "$RG_SESSION-active2"
  [ $? -eq 2 ] && echo "OK  review-gate blocks the same input without that flag" \
    || { echo "FAIL review-gate control case did not block"; FAIL=$((FAIL+1)); }
  rg_run "$RGDIR/nope.jsonl" "$RG_SESSION-missing"
  [ $? -eq 0 ] && echo "OK  review-gate fails open on an unreadable transcript" \
    || { echo "FAIL review-gate blocked with no transcript to read"; FAIL=$((FAIL+1)); }

  # 9. the stdin drain the gate added must not disturb the arming path. Run it
  #    in a throwaway repo and assert the flag it is supposed to leave, since
  #    --auto-arm exits 0 on every input and an exit code alone proves nothing.
  mkdir -p "$RGDIR/armrepo"
  echo '{"name":"armprobe"}' > "$RGDIR/armrepo/package.json"
  echo "{\"tool_input\":{\"file_path\":\"$RGDIR/armrepo/x.ts\"}}" | ( cd "$RGDIR/armrepo" && "$HOOKS_DIR/verify-gate.sh" --auto-arm >/dev/null 2>&1 )
  if [ $? -eq 0 ] && [ -f "$RGDIR/armrepo/.claude/state/needs-verify" ]; then
    echo "OK  verify-gate --auto-arm still arms after the stdin change"
  else
    echo "FAIL verify-gate --auto-arm no longer arms"; FAIL=$((FAIL+1))
  fi

  rm -f "$RGDIR"/*.jsonl "$RGDIR/err.txt" "$RGDIR/sub/subagents"/*.jsonl "$RGDIR/attr/subagents"/*.jsonl \
        "$RGDIR/attr2/subagents"/*.jsonl "$RGDIR/redo/subagents"/*.jsonl "$RGDIR/probe/subagents"/*.jsonl "$RGDIR/armrepo/package.json" "$RGDIR/armrepo/.claude/state/"* \
        "$RG_STATE/$RG_SESSION"* 2>/dev/null
  rmdir "$RGDIR/sub/subagents" "$RGDIR/sub" "$RGDIR/attr/subagents" "$RGDIR/attr" "$RGDIR/attr2/subagents" \
        "$RGDIR/attr2" "$RGDIR/redo/subagents" "$RGDIR/redo" "$RGDIR/probe/subagents" "$RGDIR/probe" "$RGDIR/armrepo/.claude/state" "$RGDIR/armrepo/.claude" "$RGDIR/armrepo" "$RGDIR" 2>/dev/null
fi

# pre-PR evidence gates: the corpus replays the five real Scheduler PRs that were
# blocked in review on 19 Aug 2026 and asserts each trips the rule that would have
# caught its blocker. It is a full suite, so run it whole rather than restating it.
CORPUS="$HOME/.claude/tests/pr-gate-fixtures/run-corpus.sh"
if [ -x "$CORPUS" ]; then
  CORPUS_OUT=$(bash "$CORPUS" 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "OK  pre-PR evidence gates ($(printf '%s' "$CORPUS_OUT" | tail -1))"
  else
    echo "FAIL pre-PR evidence gates: $(printf '%s' "$CORPUS_OUT" | grep FAIL | head -3 | tr '\n' ';')"
    FAIL=$((FAIL+1))
  fi
fi

# /auto switch: the corpus replays the four questions and the four turn-endings
# taken from real sessions, including the two where the user had to type "carry on"
# and "ok go" by hand. Full suite, so run it whole rather than restating it.
AUTOSUITE="$HOME/.claude/scripts/auto-mode-test.py"
if [ -f "$AUTOSUITE" ]; then
  AUTO_OUT=$(python3 "$AUTOSUITE" 2>&1)
  if [ $? -eq 0 ]; then
    echo "OK  auto switch ($(printf '%s' "$AUTO_OUT" | grep -E '^[0-9]+ passed' | tail -1))"
  else
    echo "FAIL auto switch: $(printf '%s' "$AUTO_OUT" | grep -E '^ +failed:' | head -3 | tr '\n' ';')"
    FAIL=$((FAIL+1))
  fi
fi

# --- fail-closed gates added 2026-09-02 from the myinsights friction data -------
# Three frictions kept recurring despite being written down AND nudged:
# assert-state (ui-state-nudge existed since July and align-dark still burned
# sessions), probe-first (a rule in workflow-rules.md that nothing enforced), and
# continuation legs with no finish line. These are the blocking versions. Each
# case asserts BOTH directions, because a gate that only ever allows is not a gate.
echo ""
echo "=== fail-closed gates (ui-state / probe / leg-scope) ==="
GFAIL=0; GPASS=0
gcase() { # gcase <label> <expected-exit> <hook+args> <json>
  local label="$1" want="$2" hook="$3" json="$4"
  printf '%s' "$json" | bash $hook >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then GPASS=$((GPASS+1)); else
    echo "FAIL $label (want exit $want, got $got)"; GFAIL=$((GFAIL+1)); fi
}
gstate() { # gstate <label> <exists|absent> <path>
  local label="$1" want="$2" path="$3"
  if { [ "$want" = exists ] && [ -f "$path" ]; } || { [ "$want" = absent ] && [ ! -f "$path" ]; }
  then GPASS=$((GPASS+1)); else echo "FAIL $label ($want expected: $path)"; GFAIL=$((GFAIL+1)); fi
}

US="$HOME/.claude/state/ui-state"; PR="$HOME/.claude/state/probe"; LG="$HOME/.claude/state/leg-scope"
S1="smoke-uis-$$"; S2="smoke-prb-$$"; S3="smoke-leg-$$"; S4="smoke-leg2-$$"
rm -f "$US"/*"$S1"* "$PR"/*"$S2"* "$LG"/*"$S3"* "$LG"/*"$S4"* 2>/dev/null

# ui-state: armed by a visual-QA prompt, blocks a style edit, opens on a real read.
printf '{"prompt":"dark mode parity looks wrong","session_id":"%s"}' "$S1" | bash "$HOOKS_DIR/ui-state-nudge.sh" >/dev/null 2>&1
gstate "ui-state arms on a visual-QA prompt" exists "$US/armed-$S1"
gcase  "ui-state blocks an unverified style edit" 2 "$HOOKS_DIR/ui-state-gate.sh" \
  "{\"session_id\":\"$S1\",\"tool_input\":{\"file_path\":\"/x/app.css\"}}"
gcase  "ui-state ignores a markdown edit" 0 "$HOOKS_DIR/ui-state-gate.sh" \
  "{\"session_id\":\"$S1\",\"tool_input\":{\"file_path\":\"/x/notes.md\"}}"
# Bypasses. The recorder used to accept any tool and any non-empty response, so
# `grep -rn data-theme src/` unlocked the gate without a browser (review finding,
# 2026-09-02). Reading the string is not reading the state.
BYP="$US/asserted-bypass-$$"
printf '%s' "{\"session_id\":\"bypass-$$\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"grep -rn data-theme src/\"},\"tool_response\":{\"stdout\":\"src/a.tsx: data-theme\"}}" \
  | bash "$HOOKS_DIR/ui-state-recorder.sh" >/dev/null 2>&1
gstate "ui-state ignores a grep for the string" absent "$BYP"
printf '%s' "{\"session_id\":\"bypass2-$$\",\"tool_name\":\"mcp__claude-in-chrome__javascript_tool\",\"tool_input\":{\"code\":\"getComputedStyle(document.body).backgroundColor\"},\"tool_response\":\"null\"}" \
  | bash "$HOOKS_DIR/ui-state-recorder.sh" >/dev/null 2>&1
gstate "ui-state ignores a query that resolved nothing" absent "$US/asserted-bypass2-$$"
# A real browser read, with a resolved value.
printf '%s' "{\"session_id\":\"$S1\",\"tool_name\":\"mcp__claude-in-chrome__javascript_tool\",\"tool_input\":{\"code\":\"getComputedStyle(document.body).backgroundColor\"},\"tool_response\":\"rgb(10, 10, 10)\"}" \
  | bash "$HOOKS_DIR/ui-state-recorder.sh" >/dev/null 2>&1
gstate "ui-state records a real browser measurement" exists "$US/asserted-$S1"
gcase  "ui-state opens once the state is known" 0 "$HOOKS_DIR/ui-state-gate.sh" \
  "{\"session_id\":\"$S1\",\"tool_input\":{\"file_path\":\"/x/app.css\"}}"
gcase  "ui-state is silent on an unarmed session" 0 "$HOOKS_DIR/ui-state-gate.sh" \
  "{\"session_id\":\"unarmed-$$\",\"tool_input\":{\"file_path\":\"/x/app.css\"}}"
# A gate with no per-Edit escape must not repeat, or it wedges the session on
# any prompt that armed it (review finding, 2026-09-02).
W="wedge-$$"
printf '%s' "{\"prompt\":\"dark mode parity looks wrong\",\"session_id\":\"$W\"}" | bash "$HOOKS_DIR/ui-state-nudge.sh" >/dev/null 2>&1
gcase "ui-state blocks the first unverified edit" 2 "$HOOKS_DIR/ui-state-gate.sh" \
  "{\"session_id\":\"$W\",\"tool_input\":{\"file_path\":\"/x/a.css\"}}"
gcase "ui-state stands down after blocking once" 0 "$HOOKS_DIR/ui-state-gate.sh" \
  "{\"session_id\":\"$W\",\"tool_input\":{\"file_path\":\"/x/a.css\"}}"
# Ordinary work must never arm a blocking gate.
printf '%s' "{\"prompt\":\"the sidebar toggle is broken, fix it\",\"session_id\":\"noarm-$$\"}" | bash "$HOOKS_DIR/ui-state-nudge.sh" >/dev/null 2>&1
gstate "ui-state does not arm on a bare themed noun" absent "$US/armed-noarm-$$"

# probe: blocks unprobed integration code, ignores prose, opens on a live probe.
gcase "probe blocks unprobed integration code" 2 "$HOOKS_DIR/probe-gate.sh" \
  "{\"session_id\":\"$S2\",\"tool_input\":{\"file_path\":\"/x/m.ts\",\"content\":\"fetch('https://graph.microsoft.com/v1.0/me')\"}}"
gcase "probe ignores a doc that merely mentions a service" 0 "$HOOKS_DIR/probe-gate.sh" \
  "{\"session_id\":\"docs-$$\",\"tool_input\":{\"file_path\":\"/x/n.md\",\"content\":\"maybe graph.microsoft.com later\"}}"
printf '{"session_id":"%s","tool_input":{"command":"curl -s https://api.figma.com/v1/me"},"tool_response":""}' "$S2" \
  | bash "$HOOKS_DIR/probe-recorder.sh" >/dev/null 2>&1
gstate "probe does not stamp on an empty response" absent "$PR/$S2--figma"
printf '%s' "{\"session_id\":\"$S2\",\"tool_input\":{\"command\":\"curl -s https://api.figma.com/v1/me\"},\"tool_response\":\"ok\"}" \
  | bash "$HOOKS_DIR/probe-recorder.sh" >/dev/null 2>&1
gstate "probe stamps a live probe" exists "$PR/$S2--figma"
gcase "probe opens once the service answered" 0 "$HOOKS_DIR/probe-gate.sh" \
  "{\"session_id\":\"$S2\",\"tool_input\":{\"file_path\":\"/x/f.ts\",\"content\":\"fetch('https://api.figma.com/v1/files')\"}}"
# Exiting on the first unstamped service turned one file into one block per
# service across successive retries (review finding, 2026-09-02).
M="multi-$$"; MJ="{\"session_id\":\"$M\",\"tool_input\":{\"file_path\":\"/x/i.ts\",\"content\":\"https://graph.microsoft.com/v1.0/me https://api.figma.com/v1/me https://api.linkedin.com/v2/me\"}}"
gcase "probe blocks a multi-service file once"  2 "$HOOKS_DIR/probe-gate.sh" "$MJ"
gcase "probe does not re-block the same file"   0 "$HOOKS_DIR/probe-gate.sh" "$MJ"
gcase "probe leaves a test suite alone"         0 "$HOOKS_DIR/probe-gate.sh" \
  "{\"session_id\":\"suite-$$\",\"tool_input\":{\"file_path\":\"/x/hooks-smoke-test.sh\",\"content\":\"https://graph.microsoft.com/v1.0/me\"}}"

# leg-scope: arms on continuation shape only, blocks until a real finish line exists.
printf '{"prompt":"continue from the reboot file","session_id":"%s"}' "$S3" | bash "$HOOKS_DIR/leg-scope.sh" --arm >/dev/null 2>&1
gstate "leg-scope arms on a continuation prompt" exists "$LG/armed-$S3"
printf '{"prompt":"add a settings toggle","session_id":"oneshot-%s"}' "$$" | bash "$HOOKS_DIR/leg-scope.sh" --arm >/dev/null 2>&1
gstate "leg-scope leaves a one-shot ask alone" absent "$LG/armed-oneshot-$$"
gcase "leg-scope never blocks writing the handoff" 0 "$HOOKS_DIR/leg-scope.sh --gate" \
  "{\"session_id\":\"$S3\",\"tool_input\":{\"file_path\":\"/h/handoffs/x.md\"}}"
# The gate had no file filter, so once armed it blocked READMEs and dotfiles too
# (review finding, 2026-09-02). Only real source should pause the session.
gcase "leg-scope leaves a README alone"  0 "$HOOKS_DIR/leg-scope.sh --gate" \
  "{\"session_id\":\"$S3\",\"tool_input\":{\"file_path\":\"/repo/README.md\"}}"
gcase "leg-scope leaves a dotfile alone" 0 "$HOOKS_DIR/leg-scope.sh --gate" \
  "{\"session_id\":\"$S3\",\"tool_input\":{\"file_path\":\"/repo/.env.example\"}}"
gcase "leg-scope blocks a source edit with no finish line" 2 "$HOOKS_DIR/leg-scope.sh --gate" \
  "{\"session_id\":\"$S3\",\"tool_input\":{\"file_path\":\"/x/a.ts\"}}"
gcase "leg-scope stands down after blocking once" 0 "$HOOKS_DIR/leg-scope.sh --gate" \
  "{\"session_id\":\"$S3\",\"tool_input\":{\"file_path\":\"/x/a.ts\"}}"
# Ordinary one-shot work must never arm a blocking gate.
printf '%s' "{\"prompt\":\"finish the login form validation\",\"session_id\":\"fin-$$\"}" | bash "$HOOKS_DIR/leg-scope.sh" --arm >/dev/null 2>&1
gstate "leg-scope leaves a one-shot 'finish the X' alone" absent "$LG/armed-fin-$$"
# Fresh session: the block path above sets the stand-down flag, so reusing it
# here would let this pass without the finish line doing any work.
printf '%s' "{\"prompt\":\"continue from the reboot file\",\"session_id\":\"$S4\"}" | bash "$HOOKS_DIR/leg-scope.sh" --arm >/dev/null 2>&1
printf '%s' "{\"session_id\":\"$S4\",\"tool_input\":{\"command\":\"echo leg-done: x\"}}" | bash "$HOOKS_DIR/leg-scope.sh" --record >/dev/null 2>&1
gstate "leg-scope rejects a token finish line" absent "$LG/stated-$S4"
# "ship it" is 7 chars and cleared the old 6-char bar (review finding).
printf '%s' "{\"session_id\":\"$S4\",\"tool_input\":{\"command\":\"echo leg-done: ship it\"}}" | bash "$HOOKS_DIR/leg-scope.sh" --record >/dev/null 2>&1
gstate "leg-scope rejects 'ship it' as a finish line" absent "$LG/stated-$S4"
printf '%s' "{\"session_id\":\"$S4\",\"tool_input\":{\"command\":\"echo leg-done: push PR 334 and get the review green\"}}" | bash "$HOOKS_DIR/leg-scope.sh" --record >/dev/null 2>&1
gstate "leg-scope accepts a real finish line" exists "$LG/stated-$S4"
gcase "leg-scope opens once the leg is scoped" 0 "$HOOKS_DIR/leg-scope.sh --gate" \
  "{\"session_id\":\"$S4\",\"tool_input\":{\"file_path\":\"/x/a.ts\"}}"

rm -f "$US"/*"$S1"* "$PR"/*"$S2"* "$LG"/*"$S3"* "$LG"/*"$S4"* "$LG"/*oneshot-$$* "$US"/*$$* "$PR"/*$$* 2>/dev/null
if [ "$GFAIL" -eq 0 ]; then
  echo "OK  fail-closed gates ($GPASS passed, 0 failed)"
else
  echo "FAIL fail-closed gates ($GPASS passed, $GFAIL failed)"
  FAIL=$((FAIL+1))
fi

# --- register-gate added 2026-09-09 ---------------------------------------------
# This gate was built in August, silently died on 25 Aug because it was registered
# with the wrong flag, and nobody noticed for two days. The wiring assertions below
# are the point: a gate that looks alive in settings.json and never runs is the
# failure mode this section exists to catch.
echo ""
echo "=== register-gate fixtures ==="
RGPASS=0; RGFAIL=0
rgcase() { # name expected_exit fixture
  local name="$1" want="$2" fx="$3" got
  printf '%s' "{\"session_id\":\"smoke-rg-$$\",\"transcript_path\":\"$fx\",\"cwd\":\"$HOME\",\"stop_hook_active\":false}" \
    | python3 "$HOOKS_DIR/register-gate.py" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then echo "OK  $name"; RGPASS=$((RGPASS+1))
  else echo "FAIL $name (exit $got, wanted $want)"; RGFAIL=$((RGFAIL+1)); fi
}

RGDIR="$(mktemp -d)"
python3 - "$RGDIR" <<'RGPY'
import json, sys, pathlib
d = pathlib.Path(sys.argv[1])
def write(name, text, entrypoint="cli"):
    rec = {"type": "assistant", "entrypoint": entrypoint,
           "message": {"content": [{"type": "text", "text": text}]}}
    (d / name).write_text(json.dumps(rec) + "\n")
write("wall.jsonl", " ".join(["word"] * 300))
write("short.jsonl", "Done. The branch is green.")
write("headless.jsonl", " ".join(["word"] * 300), entrypoint="sdk-py")
write("dash.jsonl", "This reply is fine — except for the dash in it.")
write("mid.jsonl", " ".join(["word"] * 120))
RGPY

rgcase "register-gate blocks a wall of text"            2 "$RGDIR/wall.jsonl"
rgcase "register-gate passes a short reply"             0 "$RGDIR/short.jsonl"
rgcase "register-gate exempts a headless run"           0 "$RGDIR/headless.jsonl"
rgcase "register-gate blocks an em dash"                2 "$RGDIR/dash.jsonl"
rgcase "register-gate only warns on a near-miss"        0 "$RGDIR/mid.jsonl"

# The near-miss above must have left a marker that the prompt side spends exactly once.
RGWARN="$(printf '%s' "{\"session_id\":\"smoke-rg-$$\"}" | python3 "$HOOKS_DIR/register-gate.py" --prompt)"
case "$RGWARN" in
  *"120 words"*) echo "OK  register-gate warn names the measured length"; RGPASS=$((RGPASS+1)) ;;
  *) echo "FAIL register-gate warn names the measured length (got: $RGWARN)"; RGFAIL=$((RGFAIL+1)) ;;
esac
RGWARN2="$(printf '%s' "{\"session_id\":\"smoke-rg-$$\"}" | python3 "$HOOKS_DIR/register-gate.py" --prompt)"
if [ -z "$RGWARN2" ]; then echo "OK  register-gate warn is spent once, not wallpaper"; RGPASS=$((RGPASS+1))
else echo "FAIL register-gate warn repeated itself"; RGFAIL=$((RGFAIL+1)); fi

# Wiring. Both halves or the gate is dead: bare at Stop does every check, --prompt at
# UserPromptSubmit only spends the marker and exits before any of them.
rgwired() { # name event predicate
  if python3 -c "
import json, sys, pathlib
d = json.loads((pathlib.Path.home() / '.claude/settings.json').read_text())
cmds = [h.get('command','') for m in d.get('hooks',{}).get('$2',[]) for h in m.get('hooks',[])]
sys.exit(0 if any($3) else 1)
" 2>/dev/null; then echo "OK  $1"; RGPASS=$((RGPASS+1))
  else echo "FAIL $1"; RGFAIL=$((RGFAIL+1)); fi
}
rgwired "register-gate is wired at Stop (bare)" Stop \
  "c.endswith('register-gate.py') for c in cmds"
rgwired "register-gate is wired at UserPromptSubmit (--prompt)" UserPromptSubmit \
  "c.endswith('register-gate.py --prompt') for c in cmds"

rm -f "$RGDIR"/*.jsonl
rmdir "$RGDIR" 2>/dev/null
rm -f "$HOME/.claude/state/register-gate/smoke-rg-$$".* 2>/dev/null
if [ "$RGFAIL" -eq 0 ]; then
  echo "OK  register-gate ($RGPASS passed, 0 failed)"
else
  echo "FAIL register-gate ($RGPASS passed, $RGFAIL failed)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== gateway offload + review hooks ==="
MFAIL=0; MPASS=0
mcheck() {  # name, expected exit, payload
  out="$(printf '%s' "$3" | "$HOME/.claude/hooks/gateway-offload-gate.sh" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq "$2" ]; then MPASS=$((MPASS+1)); else echo "FAIL $1 (exit $rc, wanted $2)"; MFAIL=$((MFAIL+1)); fi
}
# The gate must bite cheap subagents only, and only under real pressure. Read
# the live usage the same way the hook does, so the fixture cannot go stale.
PRESSURE="$(python3 -c "
import json,os,time
p=os.path.expanduser('~/.claude/usage-history.jsonl')
try:
    if time.time()-os.path.getmtime(p)>1800: raise SystemExit
    with open(p,'rb') as f:
        f.seek(max(0,os.path.getsize(p)-4000))
        d=json.loads(f.read().decode('utf-8','replace').strip().splitlines()[-1])
    print(1 if (d.get('seven_day',{}).get('used_percentage',0)>=92 or d.get('five_hour',{}).get('used_percentage',0)>=90) else 0)
except Exception: print(0)
" 2>/dev/null)"
[ -z "$PRESSURE" ] && PRESSURE=0
if [ "$PRESSURE" = "1" ]; then
  mcheck "offload gate denies a haiku subagent under pressure" 2 '{"tool_name":"Agent","tool_input":{"model":"haiku","prompt":"x"}}'
else
  mcheck "offload gate stands down when there is headroom" 0 '{"tool_name":"Agent","tool_input":{"model":"haiku","prompt":"x"}}'
fi
mcheck "offload gate never blocks top-tier judgment work" 0 '{"tool_name":"Agent","tool_input":{"model":"opus","prompt":"x"}}'
mcheck "offload gate fails open on an empty payload" 0 ''
GATEWAY_OFFLOAD_OK=1 mcheck "offload gate honours its bypass" 0 '{"tool_name":"Agent","tool_input":{"model":"haiku","prompt":"x"}}'
for hk in gateway-review.sh gateway-surface.sh gateway-offload-gate.sh; do
  if zsh -n "$HOME/.claude/hooks/$hk" 2>/dev/null; then MPASS=$((MPASS+1));
  else echo "FAIL $hk does not parse"; MFAIL=$((MFAIL+1)); fi
done
if zsh -n "$HOME/.claude/scripts/gateway-run.sh" 2>/dev/null; then MPASS=$((MPASS+1));
else echo "FAIL gateway-run.sh does not parse"; MFAIL=$((MFAIL+1)); fi
# A dated legacy deployment must never outrank a versioned one, or --tier deep
# silently routes to an ancient model and preflight still passes.
MT="$(mktemp)"; echo '{"data":[{"id":"claude-3-opus-20240229"},{"id":"claude-opus-5"}]}' > "$MT"
MP="$(mktemp)"
sed -n '/^pick_model()/,/^}/p' "$HOME/.claude/scripts/gateway-run.sh" | sed -n "/<<'PY'/,/^PY$/p" | sed '1d;$d' > "$MP"
if [ "$(python3 "$MP" "$MT" deep 2>/dev/null)" = "claude-opus-5" ]; then MPASS=$((MPASS+1));
else echo "FAIL gateway model picker ranks a dated id above a versioned one"; MFAIL=$((MFAIL+1)); fi
rm -f "$MT" "$MP"
if [ "$MFAIL" -eq 0 ]; then
  echo "OK  gateway hooks ($MPASS passed, 0 failed)"
else
  echo "FAIL gateway hooks ($MPASS passed, $MFAIL failed)"
  FAIL=$((FAIL+1))
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "=== ALL PASS ==="
  exit 0
else
  echo "=== $FAIL FAILURES ==="
  exit 1
fi
