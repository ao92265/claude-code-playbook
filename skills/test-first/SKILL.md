---
name: test-first
description: >
  TDD workflow that enforces writing tests before implementation. Use when building new
  features or fixing bugs where you want test-driven development discipline.
  Triggers: "tdd", "test first", "red green refactor", "write tests first".

  Do NOT use this skill for: exploratory prototyping, one-line fixes with existing test
  coverage, or refactoring where tests already exist and pass.
metadata:
  user-invocable: true
  slash-command: /test-first
  proactive: false
---

# Test-First Development

Enforce the Red-Green-Refactor cycle. Tests define the contract before implementation begins.

## Steps

1. **Understand the requirement:**
   - Clarify what the feature/fix should do
   - Identify inputs, outputs, edge cases, and error conditions
   - Ask clarifying questions if the spec is ambiguous

2. **Write failing tests (RED):**
   - Create test file(s) if they don't exist
   - Write test cases that define expected behavior
   - Include happy path, edge cases, and error cases
   - Tests should be specific and descriptive — test names explain the contract

3. **Confirm tests fail for the right reason:**
   - Run the test suite: `npm test`, `pytest`, `go test`, etc.
   - Verify failures are "function not found" or "wrong return value" — not syntax errors
   - If tests fail for the wrong reason, fix the test first

4. **Implement minimum code to pass (GREEN):**
   - Write the simplest code that makes all tests pass
   - Do not optimize or generalize yet
   - Do not add code that isn't required by a test

5. **Confirm all tests pass:**
   - Run the full test suite
   - All new tests must be green
   - All existing tests must still pass (no regressions)

6. **Refactor (REFACTOR):**
   - Clean up implementation while keeping tests green
   - Extract helpers, rename variables, simplify logic
   - Run tests after each refactoring step

7. **Final verification:**
   - Run full test suite one last time
   - Run type checker / linter if applicable
   - Show the user the test results and implementation summary

## Important

- **Never skip the RED step.** If you can't write a failing test first, you don't understand the requirement well enough.
- **Never write implementation before tests exist.** The test defines the contract.
- **Keep tests fast.** Prefer unit tests over integration tests where possible.
- **One behavior per test.** Each test should verify exactly one thing.
- **Test names are documentation.** Use descriptive names: `should_return_404_when_user_not_found`.
