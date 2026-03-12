---
name: executing-plans
description: |
  Execute a written plan file from docs/plans/ through structured batches with checkpoints.
  Only use when a plan file already exists in docs/plans/. Triggers: "execute the plan",
  "run the plan", "start working on the plan in docs/plans".

  Do NOT use this skill for: creating plans (use writing-plans), ad-hoc coding, tasks
  without a written plan file, or autonomous execution (use OMC ralph/ultrawork/autopilot
  for multi-agent execution loops).
license: MIT
compatibility: marvin
metadata:
  marvin-category: work
  user-invocable: true
  slash-command: /execute
  model: default
  proactive: false
---

# Executing Plans

Implement written plans through structured batches with review checkpoints.

## When to Use

- A plan exists in `docs/plans/`
- User says "execute the plan" or "implement the plan"
- After completing the writing-plans skill
- When resuming work on a documented plan

## Process

### Step 1: Load and Review

1. Read the plan file from `docs/plans/`
2. **Critically assess it** - Does it still make sense?
3. Raise concerns before proceeding
4. Confirm understanding with user

### Step 2: Execute Batch

Work through tasks in batches (typically 3 at a time):

1. **Mark progress** - Note which task you're on
2. **Follow steps precisely** - Don't skip verifications
3. **Run all commands** - Check they produce expected output
4. **Commit after each logical unit**

### Step 3: Report Results

After each batch, use the batch report format from `assets/execution-template.md`.

### Step 4: Continue or Adjust

Based on feedback:
- **Continue** - Execute next batch
- **Adjust** - Modify approach based on feedback
- **Pause** - Save progress and stop

### Step 5: Complete Development

When all tasks done:
1. Run final verification (all tests, linting)
2. Summarize what was built
3. Offer to commit/PR if not done

## Critical Rules

### STOP IMMEDIATELY When:

- **Missing dependency** - Something needed isn't available
- **Unclear instructions** - Plan step is ambiguous
- **Failed verification** - A check didn't pass
- **Unexpected state** - Reality doesn't match plan

**Never force through obstacles or guess at solutions.**

### Return to Review When:

- Plan needs updating
- Fundamental approach needs to change
- New information changes requirements

## Progress Tracking and Output Format

See `assets/execution-template.md` for the progress tracking block and per-task execution format.

---

*Adapted from obra/superpowers executing-plans skill*
