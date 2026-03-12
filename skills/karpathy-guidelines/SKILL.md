---
name: karpathy-guidelines
description: >
  Pre-coding checklist to prevent LLM overcomplication. Invoke explicitly via /karpathy
  when you want to apply Karpathy's simplicity guidelines before a complex implementation.
  Surfaces assumptions, enforces minimal changes, and defines verifiable success criteria.

  Do NOT auto-trigger on normal coding tasks. This is a manual checklist for complex or
  risky changes where overengineering is a concern. Don't trigger for simple edits, bug
  fixes, or when verification-before-completion already covers the verification step.
license: MIT
metadata:
  user-invocable: true
  slash-command: /karpathy
  proactive: false
---

# Karpathy Guidelines

Behavioral guidelines to reduce common LLM coding mistakes, derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## Pre-Coding Checklist

Execute all steps before writing any code. For trivial single-line changes, steps 1–2 may be abbreviated.

---

### Step 1: Surface Assumptions and Ambiguities

1. List every assumption the implementation will rely on.
2. Check whether each assumption is explicit in the request or inferred.
   - If inferred and consequential: state it aloud and ask for confirmation before proceeding.
   - If inferred and obvious: note it briefly, then continue.
3. Check whether multiple valid interpretations of the request exist.
   - If yes: present them as numbered another-projectns. Do not pick silently. Wait for the user to select one.
   - If no: continue.
4. Check whether a simpler approach exists than what was asked for.
   - If yes: surface it. Push back if warranted. Do not silently implement the more complex path.
   - If no: continue.
5. If anything remains unclear after the above checks, stop. Name exactly what is confusing. Ask.

---

### Step 2: Apply Simplicity Constraint

Before writing code, verify the planned implementation passes all of the following:

- Contains no features beyond what was explicitly requested. If any exist, remove them.
- Contains no abstractions added for a single-use case. If any exist, flatten them.
- Contains no "flexibility" or "configurability" that was not requested. If any exist, remove them.
- Contains no error handling for scenarios that cannot occur given the current inputs. If any exist, remove them.

Apply the senior-engineer test: "Would a senior engineer call this overcomplicated?"
- If yes: rewrite to the minimum viable implementation.
- If no: continue.

---

### Step 3: Apply Surgical Change Constraint

Before editing any existing file, apply these rules:

1. Identify the exact lines the request requires changing. Plan to touch only those lines.
2. Do not improve, reformat, or restructure adjacent code, comments, or formatting — even if it would be better.
3. Do not refactor code that is not broken.
4. Match the existing code style exactly, even if it differs from preferred style.
5. If unrelated dead code is noticed, mention it in the response. Do not delete it.
6. After changes are drafted, check for orphaned imports, variables, or functions created by the edits.
   - If found: remove them (these are your mess to clean up).
   - If pre-existing dead code is found: leave it. Mention it only.

Verify: every changed line traces directly to the user's request. If a line cannot be traced, remove it.

---

### Step 4: Define Verifiable Success Criteria

Before executing, transform the task into a concrete, testable goal:

| Vague request | Verifiable goal |
|---|---|
| "Add validation" | Write tests for invalid inputs, then make them pass |
| "Fix the bug" | Write a test that reproduces it, then make it pass |
| "Refactor X" | Ensure tests pass before and after, diff is minimal |

For multi-step tasks, state a brief execution plan before starting:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

If success criteria cannot be defined without clarification, return to Step 1.

---

### Step 5: Execute and Verify

1. Implement according to the plan from Steps 1–4.
2. Run the verification check defined in Step 4.
3. If verification passes: report the result with evidence.
4. If verification fails: do not claim completion. Investigate, fix, and re-run from this step.
