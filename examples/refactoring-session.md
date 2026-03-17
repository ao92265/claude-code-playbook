# Example: Refactoring Session

An annotated session showing the `/refactor` skill's zero-behavior-change workflow.

---

## Context

A 200-line function that handles user registration needs to be broken up. It works correctly but is hard to read and modify.

---

## Session Transcript

**User:**
```
Refactor src/services/user-service.ts — the registerUser function is 200 lines.
Break it into smaller functions. Zero behavior change.
Don't change any tests.
```

> **Pattern: Clear refactoring scope.** The user specifies WHAT to refactor, HOW (break into smaller functions), and the constraint (zero behavior change, don't change tests).

**Claude:**
```
First, establishing the green baseline. Running all tests.
```
*[Runs `npm test`]*
```
147 passing (3.2s)
0 failing
```

> **Step 1: Green baseline.** The refactoring skill requires all tests to pass BEFORE any changes. This is the contract — if tests still pass after, behavior is preserved.

**Claude:**
```
Reading the function to understand the logical sections.

registerUser() at line 24 does:
1. Lines 25-45: Input validation (email format, password strength, duplicate check)
2. Lines 47-82: User creation (hash password, create record, assign default role)
3. Lines 84-120: Welcome email (build template, send email, log delivery)
4. Lines 122-165: Onboarding setup (create default settings, seed sample data)
5. Lines 167-198: Audit trail (log registration event, notify admin, analytics)

I'll extract each section into a named function. One at a time.
```

> **Pattern: Understand before changing.** Claude maps the function's logical sections before touching anything.

**Claude:**
```
Step 1: Extracting input validation.
```
*[Extracts lines 25-45 into `validateRegistrationInput()` — same file]*
*[Runs `npm test`]*
```
147 passing (3.1s)
```

> **Pattern: One refactoring, then test.** Claude extracts ONE function and immediately verifies. If this broke something, the blast radius is one change.

**Claude:**
```
Step 2: Extracting user creation.
```
*[Extracts lines 47-82 into `createUserRecord()` — same file]*
*[Runs `npm test`]*
```
147 passing (3.2s)
```

**Claude:**
```
Step 3: Extracting welcome email.
```
*[Extracts lines 84-120 into `sendWelcomeEmail()` — same file]*
*[Runs `npm test`]*
```
147 passing (3.1s)
```

**Claude:**
```
Step 4: Extracting onboarding setup.
```
*[Extracts lines 122-165 into `setupOnboarding()` — same file]*
*[Runs `npm test`]*
```
147 passing (3.2s)
```

**Claude:**
```
Step 5: Extracting audit trail.
```
*[Extracts lines 167-198 into `logRegistrationEvent()` — same file]*
*[Runs `npm test`]*
```
147 passing (3.1s)
```

**Claude:**
```
Running type checker as final verification.
```
*[Runs `npx tsc --noEmit`]*
```
No errors.
```

**Claude:**
```
Refactoring complete. registerUser() is now 15 lines:

async function registerUser(input: RegisterInput): Promise<User> {
  await validateRegistrationInput(input);
  const user = await createUserRecord(input);
  await sendWelcomeEmail(user);
  await setupOnboarding(user);
  await logRegistrationEvent(user);
  return user;
}

Extracted 5 functions, all in the same file.
147 tests still passing. Types clean.
Zero behavior change — no test modifications needed.
```

---

## What Made This Session Work

1. **Green baseline first** — tests passed before starting
2. **One extraction at a time** — tested after each step
3. **Same file** — didn't create new files or modules unnecessarily
4. **Tests untouched** — tests are the behavior contract, not the refactoring target
5. **Final verification** — both tests and type checker confirm no regressions

## The Rule

If you need to change a test during a refactoring, you're not refactoring — you're changing behavior. Stop and reconsider.
