---
name: writing-plans
description: |
  Create a written implementation plan file in docs/plans/. Use when the user explicitly
  asks for a plan document before coding. Triggers: "write a plan for", "create an
  implementation plan", "document the approach before we start".

  Do NOT use this skill for: executing plans (use executing-plans instead), verbal planning
  discussions (use brainstorming), multi-agent planning (use OMC omc-plan or ralplan),
  simple tasks, single-file changes, or when the user says "how should I implement" as a
  conversational question rather than a request for a written plan file.
license: MIT
compatibility: marvin
metadata:
  marvin-category: work
  user-invocable: true
  slash-command: /plan
  model: default
  proactive: true
title: "Writing Plans"
parent: Skills & Extensibility
---
# Writing Plans

Generate comprehensive, actionable implementation plans before coding.

## When to Use

- Multi-step tasks (3+ distinct steps)
- Changes touching multiple files
- New features requiring design decisions
- User explicitly asks for a plan
- Complex refactoring or migrations

## Process

### Step 1: Announce

Say: "I'm using the writing-plans skill to create an implementation plan."

### Step 2: Understand the Task

- What's the goal?
- What constraints exist?
- What's the current state?
- Are there dependencies?

### Step 3: Write the Plan

Save to: `docs/plans/YYYY-MM-DD-{feature-name}.md`

Use the template in `assets/plan-template.md` as the starting structure.

Plan must include:
1. **Feature name and goal** - One clear sentence
2. **Architecture approach** - 2-3 sentences on the strategy
3. **Tech stack** - What tools/libraries/frameworks
4. **Exact file paths** - Every file that will be created/modified
5. **Code examples** - Complete, not abstract
6. **Commands** - Specific commands with expected outputs
7. **Verification steps** - How to know each step worked

### Step 4: Define Atomic Tasks

Each task should take 2-5 minutes. Separate:
- Write test
- Verify test fails
- Implement feature
- Verify test passes
- Commit

**Bad:** "Add user authentication"
**Good:**
1. Create `tests/auth/test_login.py` with login test
2. Run `pytest tests/auth/test_login.py` - verify FAILS
3. Create `src/auth/login.py` with login function
4. Run `pytest tests/auth/test_login.py` - verify PASSES
5. Commit: "feat(auth): add login function"

### Step 5: Offer Execution Path

After completing the plan:

> **Ready to execute?**
> - Option A: I execute the plan now (batch execution with checkpoints)
> - Option B: You execute, I guide (pair programming style)

## Principles

- **DRY** - Don't repeat yourself
- **YAGNI** - You aren't gonna need it
- **TDD** - Write tests first when practical
- **Frequent commits** - Small, atomic commits
- **Assume competence** - Don't over-explain basics

---

*Adapted from obra/superpowers writing-plans skill*
