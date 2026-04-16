---
title: Prompt Library
nav_order: 2
parent: "Patterns & Techniques"
---
# Prompt Library

50+ copy-paste prompts for every situation. Bookmark this page.

---

## How to Use This Library

1. Find the category that matches your task
2. Copy the prompt
3. Replace the `[bracketed]` parts with your specifics
4. Paste into Claude Code

Every prompt includes **why it works** — so you can adapt the pattern, not just copy the text.

---

## Bug Fixing

### The Scoped Bug Fix
```
This test fails with "[exact error message]" at [file:line].
Fix it. Only modify files in [directory]. Don't change the test.
```
**Why it works:** Exact error eliminates guessing. Scope lock prevents drift. "Don't change the test" makes success unambiguous.

### The Regression Fix
```
This worked before commit [hash]. Now it fails with [error].
Find what changed and fix the regression. Don't introduce new behavior.
```
**Why it works:** Git bisect context. Claude can diff the commit to find the breaking change.

### The Intermittent Bug
```
[Endpoint/feature] fails ~[X]% of the time with [error].
It works most of the time. Debug this systematically — form hypotheses
and test them. Don't guess.
```
**Why it works:** Forces scientific debugging instead of random changes. The frequency hint suggests race conditions or data-dependent issues.

### The "It Works Locally"
```
This works in dev but fails in [staging/prod] with [error].
Check for environment differences: env vars, database state,
API versions, network config. Don't change code until you
identify the environment difference.
```
**Why it works:** Prevents Claude from modifying working code when the issue is environmental.

### The Error Message Deep Dive
```
I'm getting this error but I don't understand what it means:
[paste full error/stack trace]
Explain what's happening, why, and what the fix is.
```
**Why it works:** Sometimes you need understanding before fixing. Claude explains the mechanism, not just the patch.

---

## Feature Development

### The Scoped Feature
```
Add [feature description] to [endpoint/component/module].
Only modify files in [directory]. [Specific constraint].
Run tests when done.
```
**Why it works:** Clear scope + constraint + verification criteria. The simplest effective prompt.

### The Reverse-Prompted Feature
```
I need to add [feature description].
Ask me 20 clarifying questions about how it should work
before you start implementing anything.
```
**Why it works:** Claude's questions reveal edge cases you haven't considered. 5 minutes of Q&A saves hours of rework.

### The Pattern-Following Feature
```
Look at how [ExistingService] is structured in [file].
Build [NewService] following the exact same pattern.
Same file structure, same naming, same error handling approach.
```
**Why it works:** Consistency. Claude matches the existing pattern instead of inventing a new one.

### The Constrained Feature
```
Add [feature]. Constraints:
- Maximum 3 files changed
- No new dependencies
- Must work with the existing [database/API/auth] system
- Include tests
```
**Why it works:** Explicit constraints prevent over-engineering. Claude optimizes within boundaries.

### The Multi-Step Feature
```
I need [large feature]. Let's break this into steps.
First, just plan the approach — what files need to change,
what's the order of operations, what are the risks?
Don't write any code yet.
```
**Why it works:** Separates planning from execution. You review the plan before committing to implementation.

---

## Refactoring

### The Extract Function
```
The [functionName] in [file] is [X] lines long.
Extract the logical sections into named helper functions.
Zero behavior change — all existing tests must still pass.
Don't change any test files.
```
**Why it works:** Clear target, clear constraint. "Zero behavior change" is the refactoring contract.

### The Rename
```
Rename [oldName] to [newName] across the entire codebase.
Update all imports, references, type definitions, and tests.
Run the type checker after to confirm nothing was missed.
```
**Why it works:** Renaming is mechanical but error-prone. Claude finds all references including strings and comments.

### The Simplify
```
Simplify [function/component] in [file].
It's currently [X] lines. The logic can be expressed more clearly.
Don't change behavior — same inputs must produce same outputs.
```
**Why it works:** "Simplify" + "don't change behavior" = cleaner code without risk.

### The Remove Dead Code
```
Find and remove unused exports, functions, and variables in [directory].
Verify each removal by checking for references across the codebase.
Don't remove anything that has callers, even indirect ones.
```
**Why it works:** Claude searches the full codebase before deleting. Safer than manual dead code removal.

---

## Testing

### The Test-First Feature
```
I need a function that [description].
Write the tests first — include happy path, edge cases, and error cases.
Then implement the minimum code to make all tests pass.
```
**Why it works:** TDD. Tests define the contract before implementation exists.

### The Missing Coverage
```
Look at [file]. Identify code paths that have no test coverage.
Write tests for the uncovered paths. Focus on error handling
and edge cases — the happy path is probably already tested.
```
**Why it works:** Targets the highest-risk gaps. Error paths are the most common source of production bugs.

### The Regression Test
```
We just fixed a bug where [description].
Write a test that specifically reproduces this bug scenario
so it can never happen again.
```
**Why it works:** Every bug fix should include a regression test. This makes it explicit.

### The Snapshot Test
```
The output of [function/component] is correct right now.
Add a snapshot test that captures the current output so we'll
know immediately if it changes unexpectedly.
```
**Why it works:** Locks in current behavior. Future changes must be intentional.

---

## Code Review

### The Focused Review
```
Review the changes in [file or git diff].
Focus on: correctness, security, and error handling.
Skip style/formatting — we have Prettier for that.
Rate each issue as Critical, High, Medium, or Low.
```
**Why it works:** Prioritized review. Skipping style means Claude focuses on what matters.

### The Security Review
```
Review [file/directory] for security vulnerabilities.
Check for: injection (SQL, command, template), XSS,
hardcoded secrets, missing auth checks, and insecure defaults.
Don't auto-fix — report findings with severity and remediation.
```
**Why it works:** Scope-limited security scan. "Don't auto-fix" keeps the human in control.

### The Architecture Review
```
I'm planning to [architectural change].
Review this approach. What could go wrong? What alternatives
should I consider? What will I regret in 6 months?
```
**Why it works:** Future-focused. "What will I regret" surfaces long-term maintenance costs.

---

## Debugging

### The Stack Trace Debug
```
Here's the full stack trace:
[paste stack trace]
Walk me through what's happening at each level.
What's the root cause and what's the fix?
```
**Why it works:** Full context. Claude can trace the execution path through the stack.

### The "Why Does This Work?"
```
This code works but I don't understand why:
[paste code]
Explain the mechanism. What would break it?
```
**Why it works:** Understanding prevents future bugs. "What would break it" reveals fragility.

### The Performance Debug
```
[Endpoint/operation] takes [X]ms but should take [Y]ms.
Profile it: where is time being spent?
Don't optimize yet — just identify the bottleneck.
```
**Why it works:** "Don't optimize yet" prevents premature optimization. Find the bottleneck first.

---

## Database

### The Migration
```
I need to add [column/table/index] to [table].
Write a migration that:
- Is reversible (include down migration)
- Handles existing data
- Won't lock the table for more than [X] seconds
Don't run it — just write the migration file.
```
**Why it works:** Explicit constraints for production safety. "Don't run it" keeps the human in control.

### The Query Optimization
```
This query is slow:
[paste query]
Explain why it's slow, suggest indexes, and rewrite it.
Show the EXPLAIN plan before and after.
```
**Why it works:** Evidence-based optimization. EXPLAIN plans prove the improvement.

---

## DevOps

### The Dockerfile Review
```
Review this Dockerfile for: image size, build cache efficiency,
security (non-root user, no secrets in layers), and best practices.
[paste Dockerfile]
```
**Why it works:** Targeted Dockerfile review catches the most common container issues.

### The CI Pipeline Fix
```
The CI pipeline fails with:
[paste CI error]
The pipeline definition is in [file].
Fix the pipeline — don't change application code.
```
**Why it works:** Scope-locked to the pipeline. Prevents Claude from "fixing" the app to make CI pass.

---

## Documentation

### The Function Documentation
```
Add JSDoc/docstring to the public functions in [file].
Include: what it does, parameters with types, return value,
and one usage example. Don't document private/internal functions.
```
**Why it works:** Public API only. Examples are more useful than verbose descriptions.

### The API Documentation
```
Document the API endpoints in [directory].
For each endpoint: method, path, request body, response shape,
status codes, and one curl example.
Format as markdown in docs/api.md.
```
**Why it works:** Structured format. Curl examples are immediately testable.

---

## Session Management

### The Fresh Start
```
Read SESSION_NOTES.md for context from my last session.
Then [task description].
```
**Why it works:** Picks up where the last session left off without polluted context.

### The Context Save
```
Before we end: write a handoff summary to SESSION_NOTES.md.
Include: what was done, what's left, decisions made, gotchas,
current branch, and test status.
```
**Why it works:** Structured handoff. The next session (or another developer) starts informed.

### The Scope Reset
```
Forget everything we discussed about [previous topic].
New task: [description].
```
**Why it works:** Explicit context boundary. Prevents bleed-through from previous tasks.

---

## Meta Prompts

### The "Don't Over-Engineer"
```
[Task description].
Make the smallest change that works. No refactoring.
No new abstractions. No "improvements" beyond what I asked.
Three similar lines are better than a premature helper function.
```
**Why it works:** Explicit anti-over-engineering. Add this to any prompt where Claude might go overboard.

### The "Prove It Works"
```
[After implementation]
Run [test command] and [build command].
Show me the full output. Don't say you're done until both pass.
```
**Why it works:** Forces real verification. "Show me the output" means actual evidence, not claims.

### The "Teach Me"
```
I'm going to implement [feature] myself.
Don't write the code — instead, guide me step by step.
Tell me what to do, I'll do it, and you verify each step.
```
**Why it works:** Learning mode. Claude becomes a tutor instead of a coder.

### The Emergency Brake
```
Stop. Revert all changes you just made.
Let's take a different approach: [new approach].
```
**Why it works:** When Claude goes down the wrong path, a clean revert + redirect is faster than iterating.

---

## Prompt Modifiers

Add these to any prompt to change Claude's behavior:

| Modifier | What It Does |
|:---------|:------------|
| `Only modify files in [dir]` | Scope lock — prevents touching unrelated code |
| `Don't change tests` | Makes test files the immutable contract |
| `Ask me N questions first` | Reverse prompting — surfaces edge cases |
| `Don't write code yet` | Planning mode — discuss before implementing |
| `Smallest change possible` | Anti-over-engineering |
| `Run tests when done` | Mandatory verification |
| `Show me the output` | Proof, not claims |
| `One file at a time` | Incremental implementation with checkpoints |
| `Follow the pattern in [file]` | Consistency with existing code |
| `No new dependencies` | Prevents dependency bloat |
