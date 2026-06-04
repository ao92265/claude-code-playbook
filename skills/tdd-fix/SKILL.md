---
name: tdd-fix
description: Strict TDD bug-fix loop. Failing test first, then minimal fix, then full CI parity (tsc -b + tests + lint) before PR. Use for bug-fix issues. Triggers "/tdd-fix", "tdd bug", "fix issue #N with tdd".
---

# TDD Fix Loop

Eliminates wrong-approach / buggy-first-pass friction by forcing red→green→ship.

## Phase 1 — RED

1. Read issue, reproduce bug locally.
2. Write a test that captures expected behavior. Test MUST fail.
3. Run `tsc -b && npm test` — confirm test fails for the RIGHT reason (not compile error, not wrong assertion).
4. Commit failing test alone: `test: failing case for #N`.

## Phase 2 — GREEN

1. Implement MINIMAL fix. No refactor, no adjacent cleanup.
2. After every edit run full CI parity:
   ```
   tsc -b && npm test && npm run lint
   ```
3. Loop until all three pass. NEVER skip a step.
4. 3 failed attempts → STOP, explain blocker, ask user.

## Phase 3 — SHIP

1. Commit fix separate from test: `fix: <one line> (#N)`.
2. `git branch --show-current` before push.
3. `gh pr create` referencing issue.

## Hard Rules

- Use `tsc -b` (CI parity), NEVER `tsc --noEmit`.
- NEVER edit `prisma/schema.prisma` without explicit user auth.
- NEVER bypass hooks (`--no-verify`, `[skip-verify]`) without user say-so.
- NEVER claim done without paste of `tsc -b && npm test && npm run lint` exit codes.
