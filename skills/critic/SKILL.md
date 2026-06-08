---
name: critic
description: One-shot adversarial plan review. Reads the active plan file or last assistant message and returns 3-10 severity-rated findings covering scope creep, symptom-vs-root-cause, missing tests, fabricated facts, and unverified assumptions. Wraps oh-my-claudecode:critic agent. Triggers "/critic", "review my plan", "plan critique", "adversarial review".
---

# /critic — Plan Review Wrapper

Adversarial second-opinion pass on a plan or proposal before execution begins.

## When to invoke

- Plan file written, before ExitPlanMode approval
- Long autopilot/ralph prompt drafted, before launch
- User asks "is this plan any good"
- After a deep-interview produced a spec, before implementation

## When NOT to invoke

- Trivial single-file changes
- Bug fixes where the fix is mechanical
- During implementation (use `code-reviewer` instead)

## Workflow

1. Identify target:
   - If active plan file exists at `~/.claude/plans/*.md` (latest mtime) → use it
   - Else use the last assistant message in conversation
   - User can pass explicit path: `/critic <path>`
2. Spawn `oh-my-claudecode:critic` agent (model=`opus`) with prompt:

   ```
   Review the attached plan. Find 3-10 specific issues across these axes:
   - Scope creep (does it sneak in unrelated changes?)
   - Symptom vs root cause (is it patching a symptom?)
   - Missing tests / verification gaps
   - Fabricated facts (file paths, function names, APIs that may not exist)
   - Unverified assumptions about codebase state, user intent, library behavior
   - Sequencing risks (steps that depend on prior unproven steps)

   Format each finding:
   - [SEVERITY: HIGH|MED|LOW] <one-line summary>
     - Location: <plan section or line>
     - Why it matters: <impact if not fixed>
     - Recommended fix: <concrete change>

   Max 10 findings. Return only the findings. No preamble, no summary.
   ```

3. Surface findings verbatim to user. Do NOT auto-edit the plan.

## Hard Rules

- Critic agent is READ-ONLY. No file edits.
- Findings include file:line where applicable.
- Severity is honest, no padding to hit a count.
- If plan is genuinely solid: return 0–2 findings + explicit "no major concerns" line. Don't manufacture issues.

## Triggers

`/critic`, "review my plan", "plan critique", "adversarial review", "second opinion on plan"
