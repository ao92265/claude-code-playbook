# Security Remediation with Claude Code

How to take vulnerability scanner findings and turn them into verified fixes using Claude Code.

---

## The Problem

Security scanners (Checkmarx, Snyk, Mend, Rapid7) find vulnerabilities. Developers fix them. The gap between "finding" and "fix" is where most teams lose time — understanding the vulnerability, finding the right remediation, applying it without breaking anything, and verifying the fix.

Claude Code closes this gap. Paste a scanner finding, Claude reads the flagged code, applies the OWASP-recommended fix, explains what was vulnerable and why, and runs tests.

---

## Supported Scanners

This workflow works with any scanner that produces structured findings. Tested with:

| Scanner | Export Format | Best For |
|:--------|:------------|:---------|
| **Checkmarx** | CSV, XML, SARIF | SAST (static analysis) — SQL injection, XSS, path traversal |
| **Snyk** | JSON, SARIF | Dependency vulnerabilities + some SAST |
| **Mend (WhiteSource)** | JSON, PDF | Open-source license and vulnerability scanning |
| **Rapid7** | CSV, JSON | DAST (dynamic analysis) — runtime vulnerabilities |
| **SonarQube** | JSON, SARIF | Code quality + security hotspots |
| **CodeQL** | SARIF | GitHub-native deep semantic analysis |

---

## The Workflow

### Step 1: Export Findings

Export your scanner results. Sort by vulnerability type — batch similar findings together for efficiency.

```
Example Checkmarx CSV row:
Vulnerability,File,Line,Severity,Category
SQL_Injection,src/api/users.ts,42,High,OWASP A03:2021
```

### Step 2: One Session Per Finding

**Critical rule:** Fix one vulnerability per Claude Code session. Don't batch unrelated fixes — context pollution leads to incomplete fixes and missed edge cases.

```
Start a fresh session:
$ claude

Paste the finding:
"Checkmarx found SQL Injection at src/api/users.ts:42, severity High,
OWASP A03:2021. Fix only this vulnerability. Do not refactor surrounding
code. Do not add unrelated improvements. Explain what was vulnerable and
why the fix works."
```

### Step 3: Claude Reads, Fixes, Explains

Claude will:
1. Read the flagged file and surrounding context
2. Identify the vulnerability pattern
3. Apply the OWASP-recommended remediation
4. Explain what was vulnerable and why
5. Run existing tests to verify nothing broke

### Step 4: Verify the Fix

After Claude's fix, verify:
- [ ] The vulnerability is actually fixed (re-run the scanner if possible)
- [ ] Existing tests still pass
- [ ] The fix follows the OWASP cheat sheet for that vulnerability type
- [ ] No new vulnerabilities were introduced

---

## OWASP Fix Patterns

Copy-paste prompts for the most common vulnerability types. Each references the relevant OWASP Cheat Sheet.

### A01:2021 — Broken Access Control

```
Scanner found broken access control at [file:line].
Fix: Add proper authorization checks before the resource access.
Reference: OWASP Access Control Cheat Sheet.
Do not refactor surrounding code. Explain what was vulnerable.
```

### A02:2021 — Cryptographic Failures

```
Scanner found cryptographic failure at [file:line].
Fix: Replace weak/missing encryption with current best practice.
Reference: OWASP Cryptographic Storage Cheat Sheet.
Do not refactor surrounding code. Explain what was vulnerable.
```

### A03:2021 — Injection (SQL, NoSQL, OS, LDAP)

```
Scanner found [SQL/NoSQL/OS/LDAP] injection at [file:line].
Fix: Use parameterized queries or prepared statements. Never concatenate
user input into queries.
Reference: OWASP SQL Injection Prevention Cheat Sheet.
Do not refactor surrounding code. Explain what was vulnerable.
```

### A04:2021 — Insecure Design

```
Scanner found insecure design pattern at [file:line].
Fix: Add input validation, rate limiting, or business logic constraints
as appropriate.
Reference: OWASP Secure Design Principles.
Do not refactor surrounding code. Explain what was vulnerable.
```

### A05:2021 — Security Misconfiguration

```
Scanner found security misconfiguration at [file:line].
Fix: Remove default credentials, disable unnecessary features, set
secure headers.
Reference: OWASP Security Misconfiguration Prevention.
Do not refactor surrounding code. Explain what was vulnerable.
```

### A06:2021 — Vulnerable and Outdated Components

```
Scanner found vulnerable dependency: [package@version].
Fix: Update to the minimum version that patches [CVE-ID]. Check for
breaking changes in the changelog. Run tests after update.
Do not update unrelated dependencies.
```

### A07:2021 — Authentication Failures

```
Scanner found authentication weakness at [file:line].
Fix: Implement proper credential handling per OWASP Authentication
Cheat Sheet. Add rate limiting, secure session management, or MFA
as appropriate.
Do not refactor surrounding code. Explain what was vulnerable.
```

### A08:2021 — Software and Data Integrity Failures

```
Scanner found integrity failure at [file:line].
Fix: Add integrity verification (checksums, signatures) for external
data, dependencies, or CI/CD pipeline inputs.
Reference: OWASP Software Supply Chain Security.
Do not refactor surrounding code. Explain what was vulnerable.
```

### A09:2021 — Security Logging and Monitoring Failures

```
Scanner found insufficient logging at [file:line].
Fix: Add security event logging for authentication, access control,
and input validation failures. Log enough to detect and investigate
incidents.
Reference: OWASP Logging Cheat Sheet.
Do not refactor surrounding code.
```

### A10:2021 — Server-Side Request Forgery (SSRF)

```
Scanner found SSRF vulnerability at [file:line].
Fix: Validate and sanitize all user-supplied URLs. Use allowlists for
permitted domains/IPs. Block requests to internal/private IP ranges.
Reference: OWASP SSRF Prevention Cheat Sheet.
Do not refactor surrounding code. Explain what was vulnerable.
```

---

## CLAUDE.md Security Remediation Template

Drop this into your project's CLAUDE.md when you're in "fix vulnerabilities" mode:

```markdown
## Security Remediation Rules

You are fixing security vulnerabilities identified by [Scanner Name].

Rules:
- Fix ONLY the flagged vulnerability. Do not refactor surrounding code.
- Do not suppress, ignore, or mark findings as false positives without explaining why.
- Always explain: what was vulnerable, why it was vulnerable, and why the fix works.
- Reference the relevant OWASP Cheat Sheet URL in your explanation.
- Run existing tests after every fix. If tests fail, fix the test issue — don't revert the security fix.
- Document the root cause in a comment at the fix site (one line only).
- Do not introduce new dependencies unless absolutely necessary for the fix.
```

---

## Batch Remediation Pipeline

For teams processing many findings:

### Setup

1. Export scanner findings as CSV or JSON
2. Sort by vulnerability type (batch similar findings)
3. Create a tracking spreadsheet or issue per finding

### Process

```
For each finding:
  1. Start a fresh Claude Code session
  2. Paste the finding with the OWASP prompt template above
  3. Review and approve the fix
  4. Run tests
  5. Commit with message: "fix(security): [OWASP-ID] [brief description]"
  6. Mark finding as fixed in your tracker
  7. Close session, start fresh for next finding
```

### Post-Fix Verification

After all findings are fixed:
1. Re-run the full scanner against the codebase
2. Verify all original findings are resolved
3. Check for new findings introduced by the fixes
4. Run the full test suite
5. Get security team sign-off

---

## What Claude Handles Well

Claude is effective at fixing **mechanical vulnerabilities** — issues with clear, well-documented remediation patterns:

| Vulnerability | Claude Effectiveness | Why |
|:-------------|:-------------------:|:----|
| SQL injection | High | Pattern: concatenation → parameterized queries |
| XSS (reflected/stored) | High | Pattern: raw output → escaped/sanitized output |
| Path traversal | High | Pattern: user input in paths → validation + sandboxing |
| Hardcoded secrets | High | Pattern: literal values → environment variables |
| Insecure dependencies | High | Pattern: old version → patched version |
| Missing auth checks | Medium | Requires understanding business logic |
| Cryptographic issues | Medium | Requires understanding threat model |
| Race conditions | Low | Requires deep architectural understanding |
| Business logic flaws | Low | Requires domain expertise beyond code |

**Rule of thumb:** If the OWASP cheat sheet has a clear "do this instead" pattern, Claude can fix it reliably. If the fix requires understanding your specific business rules, Claude needs more guidance.

---

## Integration with CI/CD

Combine with the [GitHub Actions guide](github-actions.md) for automated scanner-to-fix pipelines:

```yaml
# After scanner runs, trigger Claude to fix findings
name: Auto-Fix Security Findings
on:
  workflow_run:
    workflows: ["Security Scan"]
    types: [completed]

jobs:
  fix:
    if: github.event.workflow_run.conclusion == 'failure'
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Read the SARIF output from the security scan.
            For each HIGH severity finding, apply the OWASP-recommended fix.
            Create a PR with all fixes, one commit per finding.
          claude_args: "--max-turns 20 --model claude-sonnet-4-6"
```

**Caution:** Always have a human review security fix PRs before merging. Automated fixes are a starting point, not a final answer.
