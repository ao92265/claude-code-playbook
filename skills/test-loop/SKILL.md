---
name: test-loop
description: Merged TDD loop for bug fixes and refactors. Shared skeleton is write tests, commit baseline, change code, keep green, full CI parity gate (tsc -b + tests + lint) before shipping. Bugfix mode writes a failing test first, then a minimal fix. Refactor mode writes characterization tests pinning current behavior first, then iterates the refactor until tests stay green. Triggers "/tdd-fix", "tdd bug", "fix issue with tdd", "/refactor-loop", "characterization tests", "safe refactor", "refactor with tests first", "/test-loop". Do NOT use for greenfield features, doc-only changes, or when the user wants code immediately with no tests.
---

# Test Loop

One shared skeleton, two modes. Eliminates wrong-approach / buggy-first-pass friction and regression-on-refactor risk by forcing tests-before-code and CI parity before shipping.

## Shared skeleton

1. Write tests (mode-specific — see below)
2. Commit the tests as a baseline, separate from any behavior change
3. Change code in small increments
4. Keep tests green after every increment
5. Full CI parity gate before PR: `tsc -b && npm test && npm run lint`

## Mode selection

- Bug report, issue number, "fix X is broken" → **bugfix** mode
- Rename/restructure/extract/split/upgrade with no intended behavior change → **refactor** mode
- Ambiguous → ask the user which one before writing anything

---

## Mode: bugfix (failing-test-first)

### Phase 1 — RED

1. Read issue, reproduce bug locally.
2. Write a test that captures expected behavior. Test MUST fail.
3. Run `tsc -b && npm test` — confirm the test fails for the RIGHT reason (not a compile error, not a wrong assertion).
4. Commit failing test alone: `test: failing case for #N`.

### Phase 2 — GREEN

1. Implement MINIMAL fix. No refactor, no adjacent cleanup.
2. After every edit run full CI parity: `tsc -b && npm test && npm run lint`
3. Loop until all three pass. NEVER skip a step.
4. 3 failed attempts → STOP, explain blocker, ask user.

### Phase 3 — SHIP

1. Commit fix separate from test: `fix: <one line> (#N)`.
2. `git branch --show-current` before push.
3. `gh pr create` referencing issue.

---

## Mode: refactor (characterization-first)

For refactors with no intended behavior change: renaming/restructuring, splitting a god component, extracting a hook/util, deduping logic, migrating styles/theme without altering rendered output, or a contained library/version upgrade.

Not for: bug fixes (use bugfix mode above), feature adds, or a mechanical rename across files already covered by existing tests.

### Step 1 — Identify target + capture surface

Ask the user (if not stated) for:
- Target file/dir
- Public surface to preserve: rendered output, network calls, exposed API, side effects

### Step 2 — Write characterization tests

Generate tests that PIN current behavior:
- **React component:** Playwright snapshot of rendered DOM in 2–3 prop states + assertion on emitted network calls
- **Pure function:** Vitest cases for every observed input → output pair from existing usage (grep callers)
- **Service/class:** spec covering each public method's happy path + error paths

Tests MUST run green against unchanged code. If they fail on unchanged code, the tests are wrong — fix them before continuing.

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
   - Behavior actually changed? → revert + rethink
   - Baseline test was brittle (timing, ordering)? → harden test in a separate commit, then continue
5. Cap at 20 iterations. If goal not reached, surface to user with a diff summary.

### Step 5 — Final diff report

```
Refactor: <slug>
Baseline tests: <count>
Iterations: <n>/20
Net diff: <files changed>, +<add>/-<del>
Behavior delta: NONE (all baseline tests passing)
```

### Subagent routing (refactor mode)

- `executor` (sonnet) — write tests + refactor increments
- `verifier` (sonnet) — run suites + parse failures
- Escalate to `opus` only after 2 sonnet root-cause attempts on the same failure.

---

## Hard Rules (both modes)

- Use `tsc -b` (CI parity), NEVER `tsc --noEmit`.
- NEVER edit `prisma/schema.prisma` without explicit user auth.
- NEVER bypass hooks (`--no-verify`, `[skip-verify]`) without user say-so.
- NEVER claim done without pasting the exit codes of `tsc -b && npm test && npm run lint`.
- Root-cause failures, never symptom-patch tests to make them pass.
- Bugfix mode: 3 failed fix attempts → STOP, explain blocker, ask user.
- Refactor mode: NEVER skip the baseline test step — "I'll just be careful" is how regressions ship. Baseline tests are committed in their OWN branch/commit before any refactor commit, reviewable separately. If the 20-iteration cap is hit, surface partial progress — do not silently push half-finished work.
