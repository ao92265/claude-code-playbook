---
name: refactor
description: >
  Focused refactoring with zero behavior change guarantee. Applies rename, extract, inline,
  or simplify operations with mandatory test verification before and after.
  Triggers: "refactor", "clean up", "extract function", "rename", "simplify".

  Do NOT use this skill for: adding features, fixing bugs, or any change that alters
  behavior. Refactoring means same behavior, better structure. If tests don't exist,
  write them first using /test-first.
metadata:
  user-invocable: true
  slash-command: /refactor
  proactive: false
title: "Focused Refactor"
parent: Skills & Extensibility
---
# Focused Refactor

Improve code structure without changing behavior. Zero behavior change is non-negotiable.

## Steps

1. **Establish green baseline:**
   - Run the full test suite and confirm all tests pass
   - Run the type checker (`tsc --noEmit`, `go vet`, `cargo check`, `mypy`)
   - If tests don't exist for the code being refactored, stop and suggest using `/test-first`
   - Record the test results as the baseline

2. **Identify the refactoring:**
   - Clarify what the user wants to improve (or suggest based on code smells)
   - Common refactorings: rename, extract function/method, inline, simplify conditionals,
     remove duplication, split file, consolidate imports
   - Scope the change — one refactoring at a time

3. **Apply the refactoring:**
   - Make the minimum changes necessary
   - Update all references (imports, call sites, type definitions)
   - Preserve all public API contracts
   - Don't change test assertions — tests are the behavior contract

4. **Verify behavior is preserved:**
   - Run the full test suite again
   - Run the type checker again
   - Compare results to baseline — must be identical pass/fail

5. **If tests fail — revert immediately:**
   - `git checkout -- .` to discard changes
   - Analyze why the refactoring broke tests
   - Try a different, safer approach
   - Never fix tests to accommodate refactoring — that means behavior changed

6. **Final checks:**
   - Run linter to confirm no new warnings
   - Show the diff summary to the user
   - Confirm the refactoring achieved the intended improvement

## Important

- **Zero behavior change is the rule.** If any test fails after refactoring, revert. No exceptions.
- **Don't combine refactoring with feature work.** Refactor in one commit, features in another.
- **Tests are the contract.** If you need to change tests, you're not refactoring — you're changing behavior.
- **One refactoring per pass.** Don't rename AND extract AND simplify in one go.
- **If no tests exist, stop.** Refactoring without tests is guessing. Write tests first.
