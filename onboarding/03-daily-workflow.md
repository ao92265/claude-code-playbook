---
title: Daily Workflow
nav_order: 3
parent: Onboarding
---
# Step 3: The Daily Workflow (15 minutes)

## The Core Loop

Every productive Claude Code session follows this rhythm:

```
Start → Request → Implement → Verify → Close
```

Here's what that looks like in practice:

### 1. Start (1 minute)

```bash
cd your-project
claude
```

```
/check-env
```

Fix any issues. Then state your task.

### 2. Request (1 minute)

Write a clear, scoped request. Good format:

```
[What to do] in [which files/directory].
[Constraint]. [Verification criteria].
```

**Good examples:**

```
Fix the failing test in src/auth/login.test.ts.
The error is "Expected 200, received 401".
Only modify files in src/auth/. Don't change tests.
```

```
Add rate limiting to POST /api/login.
Max 5 attempts per minute per IP. Only modify src/auth/.
Ask me clarifying questions before you start.
```

**Bad examples:**

```
Fix the login                    ← too vague
Fix login, add dashboard, update docs  ← too many tasks
The code is broken               ← no error message
```

### 3. Implement (varies)

Claude reads files, plans the approach, and implements. Watch for:
- **Hooks firing** — type checks, lint checks after each edit
- **Claude reading before writing** — good sign it understands context
- **Scope staying focused** — alert Claude if it starts touching unrelated files

### 4. Verify (1 minute)

Always ask Claude to prove the work:

```
Run npm test and tsc --noEmit. Show me the output.
```

Never accept "this should work" without actual test output.

### 5. Close

If switching tasks: `/clear` then start new request.
If ending for the day: `/handoff` to save context for tomorrow.

## The 5 Rules

Tape these to your monitor:

1. **One task per session.** Multi-task = lower quality.
2. **Paste real errors.** Don't describe — paste.
3. **Scope-lock prompts.** "Only modify src/auth/"
4. **Verify with real tests.** "Run npm test, show output"
5. **Fresh session above 80%.** Use `/handoff` first.

## When Things Go Wrong

| Symptom | Fix |
|:--------|:----|
| Claude giving generic answers | Context polluted → `/clear` or new session |
| Claude modifying wrong files | Add scope lock: "Only modify src/X/" |
| Claude over-engineering | Add: "Smallest change possible. No refactoring." |
| Fix doesn't work after 2 attempts | New session with clearer spec |
| "Works on my machine" | Run `/check-env` first |

---

**Next: [04-skills-tour.md](04-skills-tour.md)** — Hands-on tour of key skills
