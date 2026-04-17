---
name: api-test
description: >
  Test API endpoints interactively: send requests, validate responses, check status
  codes, headers, and response shapes. Useful for manual API verification.
  Triggers: "test api", "api test", "test endpoint", "check endpoint", "curl".

  Do NOT use this skill for: writing automated test suites (use /test-first),
  load testing, or testing third-party APIs you don't control.
metadata:
  user-invocable: true
  slash-command: /api-test
  proactive: false
title: "API Endpoint Testing"
parent: Skills & Extensibility
---
# API Endpoint Testing

Interactive testing of API endpoints with validation of responses.

## Steps

1. **Identify the endpoint:**
   - URL, HTTP method, required headers
   - Authentication: Bearer token, API key, cookie, or none
   - Request body format: JSON, form data, multipart
   - Expected response: status code, content type, shape

2. **Test the happy path:**
   - Send a request with valid inputs
   - Verify: status code matches expected (200, 201, etc.)
   - Verify: response body shape matches API contract
   - Verify: response headers are correct (Content-Type, CORS, caching)
   - Record the response time

3. **Test error cases:**
   - Missing required fields → expect 400 Bad Request
   - Invalid data types → expect 400 or 422
   - Missing authentication → expect 401 Unauthorized
   - Insufficient permissions → expect 403 Forbidden
   - Non-existent resource → expect 404 Not Found
   - Verify error response includes helpful message

4. **Test edge cases:**
   - Empty strings, null values, zero, negative numbers
   - Very long strings (boundary testing)
   - Special characters and unicode
   - Empty arrays and objects
   - Pagination boundaries (page 0, page beyond last)

5. **Test idempotency (for mutating endpoints):**
   - Send the same POST/PUT request twice
   - Does it create duplicates? (it shouldn't for idempotent operations)
   - Does the response change on the second call?

6. **Report results:**

   ```
   ## API Test Results — [ENDPOINT]

   | Test | Expected | Actual | Status |
   |------|----------|--------|--------|
   | Happy path | 200 | 200 | PASS |
   | Missing auth | 401 | 401 | PASS |
   | Invalid body | 400 | 500 | FAIL |
   | ...          | ... | ... | ...    |

   Response time: Xms
   Issues found: Y
   ```

## Important

- **Use `curl` or the project's HTTP client** — don't install extra tools.
- **Don't test against production** unless the user explicitly says to.
- **Mask sensitive data** in output (tokens, passwords, PII).
- **Test one endpoint at a time** — keep the scope focused.
- **Record response times** but don't treat them as benchmarks — local testing != production performance.
