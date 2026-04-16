---
title: Skills Tour
nav_order: 4
parent: Onboarding
---
# Step 4: Skills Tour (30 minutes)

Try each of these skills in a real session. Spend ~5 minutes on each.

## Must-Know Skills

### /check-env — Environment Validation

You already used this. Run it at the start of every session.

```
/check-env
```

### /test-first — TDD Workflow

Pick a small feature or function to add. Instead of implementing first:

```
/test-first

I need a function that validates email addresses.
It should accept standard emails and reject malformed ones.
```

Watch how Claude writes failing tests first, then implements to make them pass.

### /code-review — Review Your Changes

After making changes (or at the end of a work session):

```
/code-review
```

Claude reviews your recent changes with severity ratings (Critical, High, Medium, Low) and specific suggestions.

### /debug — Scientific Debugging

If you have a bug to fix:

```
/debug

Users report intermittent 500 errors on GET /api/orders.
Error log: "Cannot read properties of undefined (reading 'email')"
```

Watch how Claude forms hypotheses, tests them with evidence, and narrows down systematically.

### /handoff — Session Summary

At the end of any session:

```
/handoff
```

Creates a structured summary. Read `SESSION_NOTES.md` to see the output.

## Good-to-Know Skills

### /explain — Understand Code

```
/explain src/middleware/auth.ts
```

Gets a layered explanation. Ask "go deeper on [part]" to drill in.

### /security-check — OWASP Scan

```
/security-check
```

Quick scan of recent changes for secrets, injection, XSS, and auth issues.

### /refactor — Zero-Behavior-Change Refactoring

```
/refactor

The handleOrder function in src/services/order-service.ts is too long.
Break it into smaller functions.
```

Watch how Claude runs tests before AND after each extraction.

### /deploy — Safe Deployment

```
/deploy
```

Runs through a deployment checklist: build, tests, env vars, git status, and explicit confirmation.

### /writing-plans — Implementation Planning

For large features:

```
/writing-plans

I need to add a notifications system with email, in-app,
and push notifications. Multiple channels, user preferences,
and delivery tracking.
```

Creates a structured plan file before any code is written.

## Skill Quick Reference

| When You Need To... | Use |
|:---------------------|:----|
| Start a session | `/check-env` |
| Write new code | `/test-first` |
| Fix a bug | `/debug` |
| Clean up code | `/refactor` |
| Review changes | `/code-review` |
| Scan for security issues | `/security-check` |
| Understand code | `/explain` |
| Plan a large feature | `/writing-plans` |
| Deploy | `/deploy` |
| End a session | `/handoff` |

See the full [workflow decision tree](../docs/workflows.md) for more.

---

**Next: [05-advanced.md](05-advanced.md)** — Advanced features
