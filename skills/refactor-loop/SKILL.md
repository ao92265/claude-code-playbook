---
name: refactor-loop
description: Characterization-test-first refactor loop. Generates Playwright/Vitest baseline tests capturing current behavior, commits them, then iterates refactor until tests stay green. Distinct from tdd-fix (bug-fix-first) — this is refactor-first. Triggers "/refactor-loop", "characterization tests", "safe refactor", "refactor with tests first".
---

# Refactor Loop — Test-Driven Safe Refactor

For *refactors* (no behavior change). Generates a behavioral safety net BEFORE touching code, then iterates the refactor until the net still holds.

## When to invoke

- Renaming/restructuring without semantic change
- Splitting a god component, extracting hook/util, deduping logic
- Migrating styles/theme without altering rendered output
- Library/version upgrade in a contained module

## When NOT to invoke

- Bug fix → use `tdd-fix`
- Feature add → use `dev-story` or normal flow
- Mechanical rename across files where existing tests already cover it

## Workflow

### Step 1 — Identify target + capture surface

Ask user (if not stated) for:
- Target file/dir
- Public surface to preserve: rendered output, network calls, exposed API, side effects

### Step 2 — Write characterization tests

Generate tests that PIN current behavior:

- **React component:** Playwright snapshot of rendered DOM in 2–3 prop states + assertion on emitted network calls
- **Pure function:** Vitest cases for every observed input → output pair from existing usage (grep callers)
- **Service/class:** Spec covering each public method's happy path + error paths

Tests MUST run green against unchanged code. If they fail on unchanged code → tests are wrong, fix them before continuing.

### Step 3 — Baseline commit

```bash
git checkout -b test/<slug>-baseline
git add <test files>
git commit -m "test(baseline): characterization tests for <target> before refactor"
```

### Step 4 — Iterate refactor

Loop, max 20 iterations:

1. Make one small refactor increment
2. Run full suite: `tsc -b && npm test && npm run lint`
3. Green → commit `refactor: <description>` and continue
4. Red → diagnose ROOT CAUSE (not symptom):
   - Was behavior actually changed? → revert + rethink
   - Was baseline test brittle (timing, ordering)? → harden test in separate commit, then continue
5. Cap at 20 iterations. If goal not reached, surface to user with diff summary.

### Step 5 — Final diff report

```
Refactor: <slug>
Baseline tests: <count>
Iterations: <n>/20
Net diff: <files changed>, +<add>/-<del>
Behavior delta: NONE (all baseline tests passing)
```

## Hard Rules

- NEVER skip the baseline test step. "I'll just be careful" is how regressions ship.
- Baseline tests committed in their OWN branch/commit before any refactor commit. Reviewable separately.
- Root-cause failures, never symptom-patch tests to make them pass.
- `tsc -b` (NOT `--noEmit`) — CI parity.
- If iteration cap hit: surface partial progress, do not silently push half-finished work.

## Subagent routing

- `executor` (sonnet) — write tests + refactor increments
- `verifier` (sonnet) — run suites + parse failures
- Escalate to `opus` only after 2 sonnet root-cause attempts on same failure.

## Triggers

`/refactor-loop`, "characterization tests", "safe refactor", "refactor with tests first", "lock in behavior before refactor"
