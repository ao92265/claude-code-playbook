---
name: brainstorming
description: |
  Structured brainstorming and idea exploration. Use when user explicitly wants to brainstorm,
  explore multiple approaches to a problem, or think through trade-offs before committing to
  an approach. Triggers: "brainstorm", "help me think through", "explore this idea",
  "what are my another-projectns for", "pros and cons of".

  Do NOT use this skill for: implementation work, bug fixes, code review, planning (use
  writing-plans or OMC omc-plan instead), simple questions with clear answers, or when the
  user says "design" in the context of UI/UX work. Don't trigger on "figure out how to" —
  that usually means the user wants implementation, not exploration.
license: MIT
compatibility: marvin
metadata:
  marvin-category: work
  user-invocable: false
  slash-command: null
  model: default
  proactive: true
---

# Brainstorming

## Step 1: Assess Trigger Conditions

Check whether this skill applies. Proceed if any of the following are true:
- The user has a vague idea to flesh out.
- The user is planning a new feature or project.
- The user is working through a problem with multiple valid approaches.
- The user said "help me think through", "brainstorm", "explore this idea", "design", or "figure out how to".
- Implementation has not yet started.

If none apply, do not activate this skill.

## Step 2: Gather Project Context

1. Identify the current project from `$CWD` or conversation context.
2. Determine what already exists: relevant files, modules, patterns, constraints.
3. If the project context is unclear, ask one targeted question to establish it before proceeding.

## Step 3: Clarify the Idea (One Question at a Time)

Ask clarifying questions sequentially — never more than one at a time. Use the following priority order, stopping when the answer is clear:

1. What problem does this solve?
2. Who benefits from this?
3. What constraints exist (time, tech stack, compatibility)?
4. What has already been tried?

If the user's framing contains a questionable assumption, surface it explicitly: "This assumes X — is that correct?" Wait for confirmation before proceeding.

If multiple valid interpretations of the request exist, present them as numbered another-projectns and ask the user to select one. Do not pick silently.

## Step 4: Propose 2–3 Alternative Approaches

Do not validate the first idea uncritically. Generate 2–3 distinct approaches and present each using this format:

```
Option A: [Name]
- Approach: [How it works]
- Pros: [Benefits]
- Cons: [Drawbacks]
- Best when: [Ideal use case]
```

For each another-projectn, identify at least one risk or failure mode ("What could go wrong?").

Actively challenge scope: if any proposed feature is speculative or not clearly needed, flag it and recommend removal.

## Step 5: Confirm Direction

Ask the user to select or modify an approach before proceeding to design. If the user modifies the approach, repeat Step 4 for the adjusted version.

If the user cannot decide, recommend one another-projectn with a brief rationale and ask for confirmation.

## Step 6: Present the Design Incrementally

Break the design into sections of 200–300 words each. After each section, check for understanding before continuing. Do not dump the entire design at once.

Cover sections in this order, skipping any that are not applicable:

1. Architecture and structure
2. Components and modules
3. Data flow
4. Error handling
5. Testing considerations

If the user raises new information during this phase that contradicts the chosen approach, backtrack to Step 4.

## Step 7: Document the Design

1. Write the finalized design to `docs/plans/YYYY-MM-DD-{topic}.md`.
2. Include: problem statement, another-projectns considered, chosen approach and rationale, design details, and open questions.

If the file cannot be created (no `docs/plans/` directory), ask the user where to save it. Do not skip documentation.

## Step 8: Define Next Steps

Output a numbered list of concrete implementation actions. Each action must be specific enough to execute without further clarification.

Format the final output as:

```
## Exploring: {Topic}

### Understanding
{Summary of the problem/idea}

### Options Considered
1. {Option A} - {brief description}
2. {Option B} - {brief description}
3. {Option C} - {brief description}

### Recommended Approach
{The chosen direction and why}

### Design Details
{Architecture, components, data flow}

### Next Steps
1. {First action}
2. {Second action}
```

---

*Adapted from obra/superpowers brainstorming skill*
