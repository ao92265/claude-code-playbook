# Example: Bug Fix Session

An annotated session showing the core Request-Implement-Verify-Close loop for fixing a bug.

---

## Context

A file upload endpoint returns `413 Payload Too Large` for images over 5MB, but the limit should be 10MB.

---

## Session Transcript

**User:**
```
This test fails with "Expected 200, received 413" when uploading a PNG > 5MB:

  test('should accept files up to 10MB', async () => {
    const file = createTestFile(6 * 1024 * 1024); // 6MB
    const res = await request(app).post('/api/upload').attach('file', file);
    expect(res.status).toBe(200);
  });

Fix the upload limit. Don't change the test. Only modify files in src/upload/.
```

> **Why this works:** The prompt includes the exact error, the failing test, a clear constraint ("don't change the test"), and a scope lock ("only modify files in src/upload/"). Claude doesn't have to guess what's wrong.

**Claude:**
```
Let me read the upload configuration.
```
*[Reads src/upload/config.ts, src/upload/middleware.ts]*

> **Pattern: Read before writing.** Claude examines the relevant files before proposing changes. This prevents blind edits that miss related constraints.

**Claude:**
```
Found it. In src/upload/middleware.ts line 12, the multer configuration has:

  limits: { fileSize: 5 * 1024 * 1024 } // 5MB

Changing this to 10MB to match the test expectation.
```
*[Edits src/upload/middleware.ts — changes `5 * 1024 * 1024` to `10 * 1024 * 1024`]*

> **Pattern: Minimal change.** Claude changed exactly one value. No refactoring, no "improvements," no touching other files.

**Claude:**
```
Running the test suite to verify.
```
*[Runs `npm test -- --grep "upload"`]*
```
  ✓ should accept files up to 10MB (142ms)
  ✓ should reject files over 10MB (89ms)
  ✓ should accept small files (34ms)

3 passing (265ms)
```

> **Pattern: Verify with real tests.** Claude ran the actual tests, didn't just say "this should fix it." The output proves the fix works and nothing else broke.

**Claude:**
```
Fix applied. The upload limit in src/upload/middleware.ts was set to 5MB —
changed it to 10MB. All 3 upload tests pass.
```

> **Pattern: Clean close.** Brief summary of what changed and proof it works. No unnecessary explanation.

---

## What Made This Session Work

1. **The prompt included the actual error** — not "the upload is broken"
2. **Scope was locked** — "only modify files in src/upload/" prevented drift
3. **The test was the contract** — "don't change the test" made success unambiguous
4. **Verification was real** — actual test output, not code inspection
5. **One task, one session** — no "while you're at it" creep

## What Would Have Gone Wrong

| Anti-Pattern | Consequence |
|-------------|-------------|
| "The upload is broken, fix it" | Claude explores the entire codebase looking for upload-related code |
| No scope lock | Claude might also "improve" error messages, add logging, refactor middleware |
| Skipping test verification | The change might compile but fail at runtime due to a second limit elsewhere |
| "Also update the docs while you're there" | Context pollution starts — Claude loses focus on the original fix |
