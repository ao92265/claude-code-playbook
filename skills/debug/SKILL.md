---
name: debug
description: >
  Structured debugging workflow using the scientific method. Form a hypothesis,
  test it, narrow down, and fix. Prevents random-walk debugging.
  Triggers: "debug", "investigate", "why is this broken", "root cause".

  Do NOT use this skill for: known fixes (just fix it), performance issues
  (use /perf-check), or environment problems (use /check-env).
metadata:
  user-invocable: true
  slash-command: /debug
  proactive: false
---

# Structured Debugging

Systematic debugging using the scientific method. No more random changes hoping something works.

## Steps

1. **Reproduce the bug:**
   - Get the exact error message, stack trace, or unexpected behavior
   - Find the minimal reproduction case
   - Confirm it's reproducible (not a flaky test or race condition)
   - If it can't be reproduced, gather more data before proceeding

2. **Form a hypothesis:**
   - Based on the error and context, what's the most likely cause?
   - List 2-3 possible causes ranked by probability
   - State what you'd expect to see if each hypothesis is correct

3. **Test the hypothesis:**
   - Add a targeted log, breakpoint, or assertion to test the top hypothesis
   - Run the reproduction case
   - Does the evidence support or refute the hypothesis?

4. **Narrow down:**
   - If hypothesis is supported: zoom in on the specific code path
   - If hypothesis is refuted: move to the next hypothesis
   - Use binary search: add a check at the midpoint of the suspected code path
   - Each step should cut the problem space in half

5. **Identify the root cause:**
   - Don't stop at the symptom — find why it's happening
   - Check: is this a data issue, logic error, race condition, or configuration problem?
   - Verify the root cause explains ALL observed symptoms

6. **Fix and verify:**
   - Make the minimum change that fixes the root cause
   - Run the original reproduction case — does it pass?
   - Run the full test suite — did the fix introduce regressions?
   - Remove any debugging artifacts (extra logs, breakpoints)

7. **Prevent recurrence:**
   - Add a test case that would have caught this bug
   - Consider: should this be in `tasks/lessons.md`?
   - Is there a class of similar bugs that should be checked?

## Important

- **Don't change code randomly.** Every change should test a specific hypothesis.
- **Don't fix symptoms.** A null check at the crash site is a band-aid — find why it's null.
- **Keep notes.** Write down hypotheses and results so you don't re-test the same thing.
- **Time-box.** If you're stuck after 3 hypotheses, step back and reconsider assumptions.
- **Remove debug artifacts.** No console.log, debugger statements, or commented-out code in the final commit.
