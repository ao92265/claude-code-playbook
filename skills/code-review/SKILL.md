---
name: code-review
description: >
  Structured code review with severity ratings and categorized feedback.
  Reviews recent changes for bugs, security issues, performance, and style.
  Triggers: "code review", "review code", "review my changes", "review the diff".

  Do NOT use this skill for: reviewing PRs from others (use pr-batch-review),
  security-only audits (use security-check), or reviewing an entire codebase.
metadata:
  user-invocable: true
  slash-command: /code-review
  proactive: false
---

# Code Review

Structured review of recent code changes with severity ratings and actionable feedback.

## Steps

1. **Identify scope:**
   - Get recent changes: `git diff` (unstaged), `git diff --cached` (staged), or `git diff HEAD~1` (last commit)
   - Ask the user if a different scope is needed
   - List all changed files and total lines changed

2. **Review for correctness (Critical/High):**
   - Logic errors: off-by-one, wrong comparisons, missing null checks
   - Race conditions in async/concurrent code
   - Resource leaks: unclosed connections, missing cleanup
   - Error handling: swallowed errors, missing catch blocks, wrong error types
   - Edge cases: empty arrays, zero values, undefined, boundary conditions

3. **Review for security (Critical/High):**
   - Injection vulnerabilities (SQL, command, template)
   - XSS: unescaped user input in output
   - Hardcoded secrets or credentials
   - Missing authentication or authorization checks
   - Insecure defaults (permissive CORS, debug mode)

4. **Review for performance (Medium):**
   - N+1 queries or unnecessary database calls
   - Missing pagination on list endpoints
   - Blocking operations in async contexts
   - Unnecessary re-renders in React components
   - Large objects in memory that could be streamed

5. **Review for maintainability (Low/Medium):**
   - Functions exceeding ~50 lines
   - Deeply nested conditionals (3+ levels)
   - Duplicated logic that should be extracted
   - Misleading variable or function names
   - Missing type annotations on public APIs

6. **Review for testing (Medium):**
   - New code paths without corresponding tests
   - Modified behavior without updated tests
   - Test assertions that don't actually verify the behavior
   - Missing edge case tests for error handling

7. **Format the review:**

   ```
   ## Code Review Summary

   **Files reviewed:** X | **Issues found:** Y

   ### Critical
   - [file:line] [description] — [suggestion]

   ### High
   - [file:line] [description] — [suggestion]

   ### Medium
   - [file:line] [description] — [suggestion]

   ### Low
   - [file:line] [description] — [suggestion]

   ### Positive
   - [what was done well]
   ```

8. **Include positives:**
   - Call out good patterns, clean abstractions, thorough error handling
   - Acknowledge when the diff is clean and well-structured

## Important

- **Be specific.** "This could be better" is useless. "Line 42: `users.find()` returns undefined if no match — add a null check before accessing `.email`" is actionable.
- **Include severity.** Not all issues are equal — Critical blocks merge, Low is nice-to-have.
- **Don't nitpick style** if there's a formatter (Prettier, gofmt, rustfmt). Focus on logic and design.
- **Suggest fixes.** Don't just point out problems — show how to fix them.
- **Acknowledge good work.** A review that's all negatives is demoralizing and often wrong.
