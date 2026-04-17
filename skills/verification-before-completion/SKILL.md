---
name: verification-before-completion
description: |
  Verification protocol for completion claims. Automatically activates when Claude is
  about to claim work is done — ensures fresh proof (test run, build, health check)
  before any "done" or "complete" statement. Prevents premature completion claims by
  requiring actual execution evidence, not just code analysis.

  Do NOT use this skill for: mid-task work, exploration, planning, or when karpathy-guidelines
  is already active (they share a verification step — don't double up).
license: MIT
compatibility: marvin
metadata:
  marvin-category: meta
  user-invocable: false
  slash-command: null
  model: default
  proactive: true
title: "Verification Before Completion"
parent: Skills & Extensibility
---
# Verification Before Completion

**Core Rule:** NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.

## Step 1: Identify the Proof Command

Before claiming any work is complete, determine the exact command that proves the claim:

| Claim type | Required proof command |
|---|---|
| "Tests pass" | Fresh test runner invocation (e.g., `pytest`, `npm test`) |
| "Bug fixed" | Test that reproduces the bug, run after the fix |
| "Deployed" | Health check or status endpoint (e.g., `curl https://api/health`) |
| "Configured" | Command that reads back the configured value |
| "Build succeeds" | Full build command (e.g., `tsc --noEmit`, `npm run build`) |
| "Complete" | All acceptance criteria individually verified |

If no proof command can be identified, do not proceed to a completion claim. Ask the user how to verify.

## Step 2: Scan Own Response for Unverified Language

Before finalizing any response that implies completion, check for the following phrases. If any are present, they must be replaced with verified evidence or removed:

| Flagged phrase | Problem |
|---|---|
| "should work now" | Conditional, not verified |
| "that should fix it" | Assumption, not proof |
| "probably passes" | Uncertainty — not verified |
| "looks good" | Visual inspection is not execution |
| "Done!" (before testing) | Premature |
| "I believe this works" | Belief is not evidence |

If any flagged phrase is found: do not publish the response. Execute Step 3 first.

## Rationalization Prevention

If you catch yourself thinking any of these, STOP and run verification instead:

| Excuse | Reality |
|---|---|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler ≠ tests |
| "Agent said success" | Verify independently — agent reports are claims, not proof |
| "Partial check is enough" | Partial proves nothing about the whole |
| "Different words so rule doesn't apply" | Spirit over letter — any implication of success counts |
| "I'll verify after I commit" | Verification gates the commit, not the other way around |

### Red Flags — Immediate STOP

- Using "should", "probably", "seems to" in a completion claim
- Expressing satisfaction before verification ("Great!", "Perfect!", "All done!")
- About to commit/push/PR without fresh verification output
- Trusting a subagent's success report without checking the diff/output yourself
- Thinking "just this once" or "it's a trivial change"
- Relying on a previous run's output instead of a fresh execution

If any red flag is present: do not publish the response. Execute Step 3 first.

## Step 3: Execute the Proof Command

1. Run the proof command identified in Step 1.
2. Use a fresh run — do not rely on cached output, previous runs, or agent-reported results.
3. Capture the full output including exit code.

If execution is blocked (no shell access, command unavailable): state this explicitly. Do not substitute a visual inspection or assumption.

## Step 4: Read and Interpret the Output

1. Read the complete output, not just the final line.
2. Check the exit code: non-zero means failure even if partial output looks successful.
3. Check whether the output matches the specific claim being made:
   - One test passing does not confirm all tests pass.
   - Linter passing does not confirm the build succeeds.
   - Agent output saying "success" does not confirm actual success.
4. If the output confirms the claim: proceed to Step 5.
5. If the output does not confirm the claim: proceed to Step 6.

## Step 5: State the Result with Evidence

Report the outcome using this structure:

```
[Action taken]. Verifying:
$ [command]
[actual output]

[Conclusion with specific evidence, e.g., "All 5 tests pass."]
```

Do not summarize the output — include it directly. Do not editorialize. Let the output speak.

## Step 6: Handle Verification Failure

If verification fails at Step 4:

1. Do not claim completion.
2. Report what actually happened: quote the relevant output lines.
3. Investigate the failure before making any further changes.
4. Apply a fix.
5. Return to Step 3. Repeat until verification passes.
6. Only after Step 4 confirms success: proceed to Step 5.

## Step 7: TDD Special Case

For test-driven development, verification requires the full red-green cycle. Apply this extended gate:

1. Write the test. Run it. Confirm it **fails** (red). If it passes without implementation, the test is invalid — rewrite it.
2. Implement the feature. Run the test. Confirm it **passes** (green).
3. Refactor if needed. Run the test again. Confirm it **still passes**.

A test that never failed proves nothing. Skip the red phase at the cost of proof validity.

---

*Adapted from obra/superpowers verification-before-completion skill*
