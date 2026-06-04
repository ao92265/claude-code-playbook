---
name: spec
description: Scaffold a spec-driven prompt before non-trivial implementation. Forces Context/Objective/Boundaries/Validation framing so the agent ships reviewable code in one pass instead of refactoring files it was never asked to touch. Triggers "/spec", "spec this out", "write a spec prompt", "scope this task".
---

# Spec

Turns a vague request into a four-part specification before any code is written. Prevents the two recurring failures: vague scope (agent rewrites working modules) and missing validation (green CI theater).

## When to use

- Before non-trivial implementation (multi-file, refactor, new feature).
- When a request reads like a conversation ("improve the API") instead of a spec.

Skip for: one-line fixes, lookups, trivial edits.

## The four parts (ALL required)

Fill every section. A blank section means STOP and ask — do not guess.

1. **Context** — What exists right now. Exact file paths, current behavior, relevant constraints. No "the codebase" — name the files.
2. **Objective** — What the change must *accomplish*, NOT what the code should look like. Describe the outcome, let the implementation follow.
3. **Boundaries** — What must NOT change. Files off-limits, behaviors to preserve, external interfaces/schemas frozen. Always include an explicit "do not modify outside X" line.
4. **Validation** — How to confirm it works. Exact test/build command + expected result. New behavior requires new tests.

## Template

```
Context: <files + current behavior + constraints>

Objective: <outcome to achieve — not code shape>

Boundaries: Do not modify <files>. Do not change <behavior/schema>.

Validation: Run <command>. <expected pass condition>. Add tests for <new behavior>.
```

## Rules

- Objective describes outcome, never implementation detail ("validate disposable emails", not "add a regex").
- Boundaries names real paths from the repo — verify they exist before listing them.
- Validation command must be runnable and its pass/fail observable. No "make sure it works".
- Respects existing repo caps (e.g. bugfix ~50-line / one-concern limits) — fold them into Boundaries.

## Output

The filled spec, ready to hand to an executor or run inline. No preamble. If a section can't be filled from available context → single batched question, then fill and proceed.
