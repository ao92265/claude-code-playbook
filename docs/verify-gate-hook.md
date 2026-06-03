---
title: Verify Gate Hook
nav_order: 42
parent: Hooks
---
# Verify Gate Hook — Force Verification Before Claude Stops

A `Stop` hook that refuses to let Claude end a session until verification passes. Inspired by the "exit 2 keeps Claude working" trick: if a Stop hook returns exit code 2, Claude is forced to continue rather than stop.

The naive version runs tsc/tests every Stop. Two problems:

1. **Pre-existing failures cause infinite loops.** Repos with baseline tsc errors trap Claude in unrelated fixes.
2. **Fires on non-coding sessions.** A quick `/ask` or doc-edit session shouldn't trigger a full type-check.

This pattern fixes both with **explicit arming + baseline diffing**: you arm the gate at task start, the hook compares current state against the captured baseline, and it only blocks if errors *regressed*.

---

## When You Want This

- TypeScript / monorepo projects where Claude often claims "done" before `tsc -b` passes
- Repos with known pre-existing failures that can't be cleaned up right now (legacy code, in-flight migration)
- Bug-fix sessions where the cost of a silent regression is high
- Pairs naturally with a `done` skill or pre-commit verifier — the gate is the safety net if those are skipped

When you don't want it: pure docs/research sessions, sandboxes, repos with no test/typecheck infra.

---

## How It Works

```mermaid
sequenceDiagram
    participant You
    participant Hook as verify-gate.sh
    participant Claude
    participant TSC

    You->>Hook: verify-gate.sh --arm
    Hook->>TSC: tsc -b (count errors)
    TSC-->>Hook: baseline = 96
    Hook->>Hook: write .claude/state/verify-baseline<br/>touch .claude/state/needs-verify
    Hook-->>You: armed
    Note over Claude: ...Claude works on task...
    Claude->>Hook: Stop event
    Hook->>TSC: tsc -b (count errors)
    TSC-->>Hook: current = 96
    Hook->>Hook: 96 ≤ 96 → pass
    Hook->>Hook: clear flag + baseline
    Hook-->>Claude: exit 0
    Claude-->>You: stops normally
```

Regression case:

```mermaid
sequenceDiagram
    participant Claude
    participant Hook
    participant TSC

    Claude->>Hook: Stop event
    Hook->>TSC: tsc -b
    TSC-->>Hook: current = 104
    Hook->>Hook: 104 > 96 (baseline) → REGRESSION
    Hook-->>Claude: exit 2 + "errors regressed (96 → 104)"
    Note over Claude: Forced to keep working
    Claude->>Claude: fix the 8 new errors
    Claude->>Hook: Stop event
    Hook->>TSC: tsc -b → 96
    Hook-->>Claude: exit 0, flag cleared
```

---

## The Script

`hooks/verify-gate.sh` — drop into any repo and reference it from `~/.claude/settings.json`:

```bash
#!/bin/bash
# verify-gate.sh — Stop hook + baseline arming.
#
# Modes:
#   --arm       : capture current tsc error count as baseline, set flag, exit 0.
#   --auto-arm  : PreToolUse(Edit|Write) mode. Reads tool_input JSON from stdin.
#                 If the edited file is source + in a JS/TS repo + not already
#                 armed, set the flag and capture baseline in the BACKGROUND.
#                 Always exits 0 — never blocks an edit. "Set and forget" arming.
#   (none)      : Stop-hook mode. Block stop (exit 2) only if errors REGRESSED.
#                 Flag absent → exit 0 (no-op).
#
# Files (under repo's .claude/state/):
#   needs-verify       — empty marker
#   verify-baseline    — `tsc_errors=<N>` snapshot at arm time
#   verify-gate.log    — output log

set -u

find_repo() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/package.json" ] || [ -d "$dir/.git" ]; then
      echo "$dir"; return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

find_flag_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/.claude/state/needs-verify" ] && { echo "$dir"; return 0; }
    dir=$(dirname "$dir")
  done
  return 1
}

count_tsc_errors() {
  local repo="$1"
  cd "$repo" || return 0
  [ -f tsconfig.json ] || { echo 0; return; }
  local out
  if grep -q '"build"' package.json 2>/dev/null && grep -q 'tsc -b\|tsc --build' package.json 2>/dev/null; then
    out=$(npx --no-install tsc -b 2>&1 || true)
  else
    out=$(npx --no-install tsc --noEmit 2>&1 || true)
  fi
  echo "$out" | grep -cE 'error TS[0-9]+'
}

# --auto-arm: PreToolUse(Edit|Write). Non-blocking — always exits 0.
if [ "${1:-}" = "--auto-arm" ]; then
  INPUT=$(cat)
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  [ -z "$FILE_PATH" ] && exit 0
  case "$FILE_PATH" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.vue|*.svelte) ;;   # source files only
    *) exit 0 ;;
  esac
  REPO=$(find_repo) || exit 0
  [ -f "$REPO/package.json" ] || exit 0                      # JS/TS repos only
  [ -f "$REPO/.claude/state/needs-verify" ] && exit 0        # already armed
  mkdir -p "$REPO/.claude/state"
  touch "$REPO/.claude/state/needs-verify"                   # arm immediately (race-free)
  # PreToolUse fires before the edit lands, so baseline ≈ pre-edit state.
  # Run it backgrounded so the edit is never delayed.
  ( N=$(count_tsc_errors "$REPO"); echo "tsc_errors=$N" > "$REPO/.claude/state/verify-baseline" ) >/dev/null 2>&1 &
  exit 0
fi

if [ "${1:-}" = "--arm" ]; then
  REPO=$(find_repo) || { echo "verify-gate: no repo found from $PWD" >&2; exit 1; }
  mkdir -p "$REPO/.claude/state"
  N=$(count_tsc_errors "$REPO")
  echo "tsc_errors=$N" > "$REPO/.claude/state/verify-baseline"
  touch "$REPO/.claude/state/needs-verify"
  echo "verify-gate: armed. baseline tsc errors=$N" >&2
  exit 0
fi

REPO_ROOT=$(find_flag_root) || exit 0
LOG="$REPO_ROOT/.claude/state/verify-gate.log"
BASELINE="$REPO_ROOT/.claude/state/verify-baseline"
FLAG="$REPO_ROOT/.claude/state/needs-verify"
mkdir -p "$(dirname "$LOG")"

# No baseline yet → auto-arm's background capture hasn't finished (or never ran).
# Without a trusted baseline we can't tell a regression from a pre-existing error,
# so clear the flag and pass rather than block falsely.
if [ ! -f "$BASELINE" ]; then
  echo "[verify-gate] $(date '+%F %T') no baseline — pass" >> "$LOG"
  rm -f "$FLAG"
  exit 0
fi
BASE=$(grep -oE 'tsc_errors=[0-9]+' "$BASELINE" | cut -d= -f2)
BASE=${BASE:-0}
CUR=$(count_tsc_errors "$REPO_ROOT")

{
  echo "[verify-gate] $(date '+%F %T')"
  echo "  baseline_tsc_errors=$BASE"
  echo "  current_tsc_errors=$CUR"
} >> "$LOG"

if [ "$CUR" -gt "$BASE" ]; then
  cd "$REPO_ROOT"
  if grep -q '"build"' package.json 2>/dev/null && grep -q 'tsc -b\|tsc --build' package.json 2>/dev/null; then
    npx --no-install tsc -b 2>&1 | tail -30 >> "$LOG"
  else
    npx --no-install tsc --noEmit 2>&1 | tail -30 >> "$LOG"
  fi
  echo "VERIFICATION FAILED: tsc errors regressed ($BASE → $CUR). See $LOG. Flag still set." >&2
  exit 2
fi

if [ -f "$REPO_ROOT/package.json" ] && grep -q '"test"' "$REPO_ROOT/package.json" \
   && ! grep -q '"test": *"echo' "$REPO_ROOT/package.json"; then
  cd "$REPO_ROOT"
  if ! npm test --silent >> "$LOG" 2>&1; then
    echo "VERIFICATION FAILED: tests failed. See $LOG. Flag still set." >&2
    exit 2
  fi
fi

rm -f "$FLAG" "$BASELINE"
echo "[verify-gate] PASS — flag + baseline cleared" >> "$LOG"
exit 0
```

---

## Wiring It Into Settings

Add a `Stop` entry in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/verify-gate.sh",
            "timeout": 180,
            "statusMessage": "Verify gate: running tsc + tests..."
          }
        ]
      }
    ]
  }
}
```

`timeout` should be generous enough for a full `tsc -b` on the largest repo you'll arm.

### Optional: auto-arm on every code edit

If you'd rather never think about arming, wire `--auto-arm` as a `PreToolUse` hook on `Edit|Write`. The first time Claude edits a source file in a JS/TS repo, the gate arms itself (baseline captured in the background) and the Stop hook takes over from there:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/verify-gate.sh --auto-arm",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

The hook is non-blocking (always exits 0) and the baseline capture is backgrounded, so it adds no latency to the edit itself. It only fires for source extensions (`.ts/.tsx/.js/.jsx/.mjs/.cjs/.vue/.svelte`) in repos with a `package.json`, and arms at most once per session. See the [design note](#design-notes) on the tradeoff vs. explicit arming.

---

## Daily Workflow

```bash
# 1. Start work on a task — arm the gate first
~/.claude/hooks/verify-gate.sh --arm
# verify-gate: armed. baseline tsc errors=96

# 2. Work normally. Claude edits, runs tests, etc.

# 3. When Claude tries to stop:
#    - If tsc error count is ≤ baseline AND tests pass → flag cleared, stops
#    - If errors grew → exit 2, Claude is forced to keep working

# 4. Manual override at any time:
rm .claude/state/needs-verify
```

---

## Design Notes

**Why baseline diffing instead of strict pass?** Most enterprise codebases have at least some pre-existing tsc noise. A strict gate punishes Claude for things that were already broken, and you get infinite loops on every Stop. Baseline diffing enforces "don't make it worse" — which is the actual contract you want.

**Explicit arm vs. auto-arm — which to use?** The original design favored an explicit `--arm` for two reasons:

1. **Cost.** A full `tsc -b` on a large monorepo is 30–120s. Running it on every Stop, including non-code chats, is wasteful.
2. **Intent.** The arm step is a deliberate signal: "I am about to give Claude a task where regressions matter." Chat sessions, exploration, and doc edits don't get armed.

The `--auto-arm` mode keeps both properties while removing the manual step: it only fires for **source-file** edits in a **JS/TS repo** (so docs/chat/exploration never arm), and it captures the baseline **in the background** at the first edit (so the edit itself pays no latency cost). The cost objection moves entirely to Stop time — where you wanted the check anyway. The remaining tradeoff is *intent*: auto-arm assumes "if Claude is editing source, regressions matter," which is true for almost every coding session but does mean you can't cheaply opt a single session out (delete `.claude/state/needs-verify` to abort). Use explicit `--arm` when you want per-task control; use `--auto-arm` when you want a standing safety net you never have to remember.

**Why exit 2, not just a message?** Claude Code interprets exit 2 from a Stop hook as "you must continue." Any other exit (including 1) is treated as a non-blocking warning and the session ends. This is the only reliable way to force iteration.

**Pairing with a `done` skill.** If you have a `/done` skill that runs full verification, make it clear the flag on success: `rm -f .claude/state/needs-verify .claude/state/verify-baseline`. The skill becomes the manual exit, the hook becomes the safety net for sessions where the skill was forgotten.

**Pairing with pre-commit.** This is upstream of the commit gate. By the time pre-commit fires, the gate has already either passed or forced a retry. Pre-commit becomes redundant for armed sessions, but stays valuable for unarmed ones.

---

## Failure Modes

| Symptom | Cause | Fix |
|---|---|---|
| Hook never fires | Stop entry missing or path wrong in settings.json | Validate with `python3 -m json.tool < ~/.claude/settings.json` |
| Loops forever on unrelated errors | Forgot to arm; baseline = 0 | Run `--arm` to capture real baseline |
| Stops without verifying | Flag absent (forgot to arm) | Expected — gate is opt-in per task |
| Tests run on docs-only repos | `package.json` has a real test script | Move the test script behind a separate package, or skip arming for that repo |
| Times out | `tsc -b` exceeds hook timeout on large monorepo | Increase `timeout` in settings.json; consider `--noEmit` instead of `-b` |
| Auto-arm session stops without verifying | Stopped before the background baseline finished writing | Expected — the no-baseline guard passes rather than block falsely. Longer sessions (the ones that matter) always catch up. |

---

## Related

- **[Audit Log Hook](audit-log-hook.md)** — `UserPromptSubmit` hook for compliance logging. Different lifecycle, same pattern of leaning on hooks for deterministic enforcement.
- **[Steering Files](steering-files.md)** — house rules for AI-generated code. Hooks enforce what rules describe.
- **[Harness Pattern](harness-pattern.md)** — verify gate is a concrete instance of the "comprehension check" from the harness pattern.
