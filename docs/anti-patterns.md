---
title: Anti-Patterns
nav_order: 3
parent: "Patterns & Techniques"
---
# Anti-Patterns: 20 Things That Go Wrong with Claude Code

These are the most common mistakes from 900+ sessions. Each one has burned real hours. Learn from our pain.

---

## Prompting Anti-Patterns

### 1. The Vague Request

**Don't:** "Make the code better"

**Why it fails:** "Better" is undefined. Claude will refactor everything, add logging, change variable names, and restructure files — none of which you asked for.

**Do instead:** "Extract the validation logic from `handleSubmit` in `src/forms/Login.tsx` into a separate `validateLoginForm` function in the same file."

---

### 2. The Kitchen Sink

**Don't:** "Fix the login bug, add the dashboard widget, and update the docs"

**Why it fails:** Multi-task prompts create context pollution. By task three, Claude has two failed approaches and a debug trace in context, producing worse code for each subsequent task.

**Do instead:** One task per session. Three separate sessions. Each one starts fresh.

---

### 3. The Missing Error

**Don't:** "The build is broken. Fix it."

**Why it fails:** Claude has to guess what the error is, explore the entire codebase, and try multiple approaches — burning context tokens on investigation instead of fixing.

**Do instead:** "The build fails with: `TypeError: Cannot read property 'map' of undefined` at `src/components/UserList.tsx:42`. Fix it."

---

### 4. The Iterative Spiral

**Don't:** "That's not quite right. Try again." (repeated 5 times)

**Why it fails:** Each failed attempt stays in context. By attempt 4, Claude is trying to avoid all previous failures simultaneously, producing over-cautious, convoluted code.

**Do instead:** After 2 failed attempts, start a fresh session with a clearer spec that addresses what went wrong.

---

### 5. The Premature "Looks Good"

**Don't:** "Looks good, ship it" (without running tests)

**Why it fails:** Code that looks correct often isn't. The 10% that looks right but fails at runtime becomes a production bug.

**Do instead:** "Run `npm test` and `npx tsc --noEmit`. Show me the output. Don't say done until both pass."

---

## Workflow Anti-Patterns

### 6. Planning and Coding in the Same Session

**Don't:** Discuss 3 approaches, reject 2, then ask Claude to implement the winner.

**Why it fails:** The rejected approaches pollute context. Claude writes defensive, over-engineered code trying to avoid the failure modes you discussed.

**Do instead:** Plan in session 1, save the decision to a file. Start session 2 with "Read `PLAN.md` and implement it."

---

### 7. Never Starting Fresh

**Don't:** Keep `/compact`-ing and pushing through at 80%+ context usage.

**Why it fails:** Compressed context loses nuance. Claude starts giving generic, safe answers instead of specific, correct ones. Quality degrades silently.

**Do instead:** Start fresh above 80%. Write a handoff note (`/handoff`) so the new session has context.

---

### 8. Skipping Verification

**Don't:** Accept code changes based on Claude saying "this should work."

**Why it fails:** "Should work" means "I analyzed the code and believe it's correct" — not "I ran it and confirmed." These are very different confidence levels.

**Do instead:** Always run actual tests, builds, or workflows. Real output > code analysis.

---

### 9. Blaming the Environment

**Don't:** "Your code must be wrong" (when the env is misconfigured).

**Why it fails:** Claude will endlessly modify correct code trying to fix an environment issue. You waste an hour before checking that Docker isn't running.

**Do instead:** Run `/check-env` at session start. Verify the environment before assuming the code is wrong.

---

### 10. Unbounded Context Files

**Don't:** Append to SESSION_NOTES.md, PROGRESS.md, or TODO.md without limit.

**Why it fails:** Files that grow unbounded silently exceed what Claude reads. After ~30 lines, Claude may drop the file entirely without warning.

**Do instead:** Replace the entire file content. Keep shared context files under 30 lines.

---

## Agent Anti-Patterns

### 11. Spawning Too Many Agents

**Don't:** Spawn 6-8 parallel agents for maximum throughput.

**Why it fails:** API rate limits, credential contention, and memory pressure. Agents start failing, retrying, and producing inconsistent results.

**Do instead:** Cap at 3-4 agents. Quality and reliability beat raw parallelism.

---

### 12. Agents Sharing Worktrees

**Don't:** Let multiple agents work on the same git worktree.

**Why it fails:** Agents overwrite each other's files, create merge conflicts, and corrupt the working tree. `git add -A` from one agent stages another agent's half-finished work.

**Do instead:** Each agent gets its own worktree. Parent merges results.

---

### 13. No Verification After Agent Work

**Don't:** Trust that individual agent successes mean the combined result works.

**Why it fails:** Agent A's API changes may break Agent B's frontend code. Each passes its own tests, but integration fails.

**Do instead:** Always run the full test suite after merging agent results. Integration > unit.

---

### 14. Using Opus for Everything

**Don't:** Default every sub-agent to `model: "opus"` for maximum quality.

**Why it fails:** 5x cost increase with minimal quality improvement for simple tasks. Haiku and Sonnet handle 95% of sub-agent work perfectly.

**Do instead:** Haiku for searches, Sonnet for implementation, Opus only for architecture and complex debugging.

---

## Code Anti-Patterns

### 15. The Unsolicited Refactor

**Don't:** Ask Claude to fix a bug and accept when it also refactors surrounding code.

**Why it fails:** Refactoring mixed with bug fixes makes it impossible to verify the fix in isolation. If the refactored code breaks something, you can't tell if it was the fix or the refactor.

**Do instead:** Add "Fix ONLY this bug. No refactoring. No improvements. Minimum lines changed." to your prompt.

---

### 16. The Premature Abstraction

**Don't:** Let Claude create helpers, utilities, and abstractions for one-time operations.

**Why it fails:** Three similar lines of code are better than a premature abstraction. The abstraction adds indirection, a new file to maintain, and a name to remember — for something used once.

**Do instead:** Add to CLAUDE.md: "Three similar lines are better than a premature abstraction."

---

### 17. Over-Engineering Error Handling

**Don't:** Let Claude add try/catch, fallbacks, and validation for scenarios that can't happen.

**Why it fails:** Defensive code for impossible scenarios obscures the actual logic. Readers waste time understanding error paths that never execute.

**Do instead:** Trust internal code and framework guarantees. Only validate at system boundaries.

---

### 18. The God Commit

**Don't:** Let Claude `git add -A && git commit` after implementing 5 features.

**Why it fails:** Can't revert individual changes, can't bisect bugs, can't review meaningfully. One bad feature takes down four good ones.

**Do instead:** One commit per logical change. Stage specific files by name.

---

## Configuration Anti-Patterns

### 19. No CLAUDE.md

**Don't:** Start a session without a CLAUDE.md in the project.

**Why it fails:** Claude uses generic patterns instead of your project's conventions. Every session starts with Claude learning your stack from scratch.

**Do instead:** Copy a template from this playbook. 5 minutes of setup saves 10-20 minutes per session.

---

### 20. Stale Lessons Learned

**Don't:** Write `tasks/lessons.md` once and never update it.

**Why it fails:** Lessons rot. Your stack changes, conventions evolve, and outdated lessons create contradictory instructions. Claude follows the stale advice because it's in a trusted file.

**Do instead:** Review lessons monthly. Delete ones that no longer apply. Update ones that have evolved.

---

### 21. Cognitive Debt

**Don't:** Let AI generate code without specs, reviews, or design phases — "vibe coding"

**Why it fails:** Karpathy himself renamed "vibe coding" to "agentic engineering" one year after coining it. At scale, 1% vulnerability rate × 1,000 PRs/week = 10 new security holes per week. Without specs, there's no reasoning to follow when debugging. Without reviews, context collapse accumulates as "cognitive debt" — the cost of poorly managed AI interactions.

**Do instead:** Write spec first → break into scoped tasks → review every diff with PR rigor → test relentlessly. The governance structure is the product, not the code generation.

---

## Quick Reference

| # | Anti-Pattern | Fix |
|---|-------------|-----|
| 1 | Vague request | Be specific about files, functions, and expected behavior |
| 2 | Kitchen sink | One task per session |
| 3 | Missing error | Paste the actual error message |
| 4 | Iterative spiral | Fresh session after 2 failed attempts |
| 5 | Premature "looks good" | Run tests before accepting |
| 6 | Plan + code same session | Separate sessions for planning and execution |
| 7 | Never starting fresh | New session above 80% context |
| 8 | Skipping verification | Always run real tests/builds |
| 9 | Blaming the environment | Check env before blaming code |
| 10 | Unbounded context files | Replace, don't append. Keep under 30 lines |
| 11 | Too many agents | Cap at 3-4 |
| 12 | Shared worktrees | One worktree per agent |
| 13 | No integration verification | Full test suite after merging agent work |
| 14 | Opus for everything | Route models by task complexity |
| 15 | Unsolicited refactor | "Fix ONLY this bug" in prompt |
| 16 | Premature abstraction | Three similar lines > one abstraction |
| 17 | Over-engineering errors | Validate at boundaries only |
| 18 | God commit | One commit per logical change |
| 19 | No CLAUDE.md | Copy a template from this playbook |
| 20 | Stale lessons | Review and prune monthly |
| 21 | Cognitive debt | Spec → scoped tasks → PR review → test. Governance is the product |
