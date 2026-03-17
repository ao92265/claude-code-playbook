---
name: security-check
description: >
  Quick security scan of recent changes. Checks for OWASP Top 10 patterns including
  hardcoded secrets, injection vulnerabilities, XSS, and insecure dependencies.
  Triggers: "security check", "security scan", "check for vulnerabilities", "audit security".

  Do NOT use this skill for: full penetration testing, compliance audits, or reviewing
  code that hasn't changed recently. This is a quick scan, not a comprehensive audit.
metadata:
  user-invocable: true
  slash-command: /security-check
  proactive: false
---

# Security Check

Quick security scan focused on recent changes. Checks for OWASP Top 10 patterns.

## Steps

1. **Identify scope:**
   - Get recently changed files: `git diff --name-only HEAD~5` (or since last tag)
   - If no recent changes, scan staged files or ask the user for scope

2. **Scan for hardcoded secrets (CRITICAL):**
   - API keys: patterns like `AKIA`, `sk-`, `ghp_`, `xox[bpas]-`
   - Passwords: `password\s*=\s*["']`, `secret\s*=\s*["']`
   - Private keys: `-----BEGIN.*PRIVATE KEY-----`
   - Connection strings with embedded credentials
   - JWT tokens: `eyJ` prefixed strings
   - Report file and line number for each finding

3. **Check for injection vulnerabilities (HIGH):**
   - SQL injection: string concatenation in SQL queries, missing parameterized queries
   - Command injection: unsanitized input in `exec()`, `spawn()`, `system()`, `eval()`
   - Template injection: user input in template strings without escaping
   - Path traversal: user input in file paths without validation

4. **Check for XSS patterns (HIGH):**
   - `dangerouslySetInnerHTML` with user-controlled content
   - `innerHTML` assignments with dynamic content
   - Unescaped output in templates (e.g., `{!! !!}` in Blade, `| safe` in Jinja)

5. **Check for authentication/authorization issues (HIGH):**
   - Missing auth middleware on new routes
   - Overly permissive CORS (`Access-Control-Allow-Origin: *`)
   - Missing CSRF protection on state-changing endpoints
   - Hardcoded JWT secrets or weak signing algorithms

6. **Check dependencies (MEDIUM):**
   - Run `npm audit` / `pip audit` / `cargo audit` as appropriate
   - Flag any critical or high severity vulnerabilities
   - Check for known vulnerable package versions

7. **Check for information disclosure (MEDIUM):**
   - Stack traces exposed in error responses
   - Debug mode enabled in production configs
   - Verbose logging of sensitive data (passwords, tokens, PII)

8. **Report findings:**
   - Group by severity: Critical, High, Medium, Low
   - Include file path, line number, and code snippet for each finding
   - Provide specific remediation advice for each issue
   - Summarize: total findings by severity, overall risk assessment

## Important

- **Don't auto-fix security issues** — report and recommend. Security fixes need careful review.
- **False positives are OK** — it's better to flag something harmless than miss a real vulnerability.
- **Focus on recent changes** — this is a quick scan, not a full audit.
- **Never expose actual secrets in the report** — redact sensitive values.
