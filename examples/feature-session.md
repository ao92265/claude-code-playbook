---
title: Feature Session
nav_order: 3
parent: Examples
---
# Example: New Feature Session

An annotated session showing how to build a new feature with reverse prompting, scope constraints, and multi-file verification.

---

## Context

Adding rate limiting to a login endpoint — max 5 attempts per minute per IP.

---

## Session Transcript

**User:**
```
Add rate limiting to the login endpoint — max 5 attempts per minute per IP.
Only modify files in src/auth/. Don't touch tests or other modules.
Ask me clarifying questions before you start.
```

> **Pattern: Reverse prompting.** "Ask me clarifying questions" lets Claude surface edge cases you haven't considered. Your domain knowledge + Claude's pattern recognition = better specs.

**Claude:**
```
Before I implement this, a few questions:

1. What should happen when the rate limit is hit? Return 429 with a Retry-After header, or a custom error response?
2. Should the rate limit reset on successful login, or is it a sliding window regardless?
3. Where should rate limit state live? In-memory (resets on restart), Redis, or database?
4. Should rate limiting apply to all auth endpoints or just POST /login?
5. Do you want rate limit headers on every response (X-RateLimit-Remaining, etc.)?
6. Should blocked IPs be logged for security monitoring?
```

> **Why this matters:** Questions 2 and 3 reveal architectural decisions that would have been silently assumed. Question 6 surfaces an operational concern. Better to answer 6 questions now than debug 6 wrong assumptions later.

**User:**
```
1. Return 429 with Retry-After header showing seconds until reset
2. Sliding window — failed or successful, all attempts count
3. In-memory with a Map for now. We'll move to Redis later.
4. Just POST /login
5. Yes, include X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset
6. Yes, log at warn level with the IP address
```

**Claude:**
```
Clear. Here's my approach:

1. Create src/auth/rate-limiter.ts — in-memory sliding window rate limiter
2. Update src/auth/login.ts — add rate limit middleware to the login route
3. Add rate limit headers to all login responses

Let me implement this.
```
*[Creates src/auth/rate-limiter.ts — RateLimiter class with sliding window Map]*
*[Edits src/auth/login.ts — adds rate limit check before auth logic]*

> **Pattern: State the plan briefly, then execute.** No 50-line design document — just enough to confirm alignment, then straight to implementation.

**Claude:**
```
Running the existing auth tests to verify nothing broke.
```
*[Runs `npm test -- --grep "auth"`]*
```
  ✓ should login with valid credentials (89ms)
  ✓ should reject invalid password (45ms)
  ✓ should reject unknown user (42ms)
  ✓ should return JWT on success (91ms)

4 passing (267ms)
```

**Claude:**
```
Existing tests pass. Running type checker.
```
*[Runs `npx tsc --noEmit`]*
```
No errors found.
```

> **Pattern: Two-step verification.** Tests pass AND types are clean. Either one alone isn't enough — tests can pass with type errors, and types can be clean with broken logic.

**Claude:**
```
Implementation complete. Created:

- src/auth/rate-limiter.ts — Sliding window rate limiter using in-memory Map
  - 5 requests per 60-second window per IP
  - Auto-cleanup of expired entries every 60 seconds
  - Exports: checkRateLimit(ip) → { allowed, remaining, resetTime }

- Modified src/auth/login.ts — Added rate limit check at line 15
  - Returns 429 with Retry-After header when limit exceeded
  - Adds X-RateLimit-* headers to all responses
  - Logs blocked attempts at warn level

All existing auth tests pass. Types clean.
```

---

## What Made This Session Work

1. **Reverse prompting surfaced hidden decisions** — the user answered 6 questions instead of debugging 6 wrong assumptions
2. **Scope was explicit** — "only src/auth/" prevented touching unrelated code
3. **Plan was brief** — 3 bullet points, not a design document
4. **Verification was two-step** — tests AND type checker
5. **Summary was structured** — files created/modified, what each does, proof it works

## Common Mistakes to Avoid

| Mistake | Better Approach |
|---------|----------------|
| "Add rate limiting" (no details) | Specify endpoint, limits, behavior on exceed, storage |
| Skipping clarifying questions | Ask for 5-10 questions — the answers become your spec |
| Implementing + writing tests in one pass | Implement against existing tests, then write new tests separately |
| "Looks good" without running anything | Always run tests and type checker before accepting |
