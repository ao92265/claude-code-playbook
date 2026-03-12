---
name: dependency-audit
description: >
  Run a comprehensive dependency audit for a Node.js project. Checks for vulnerabilities,
  outdated packages, and unused dependencies.

  Do NOT use this skill for: non-Node.js projects (no package.json), adding new dependencies,
  code review of application logic, or tasks unrelated to package health. Don't trigger just
  because you're working in a Node.js project — only use when explicitly auditing dependencies.
context: fork
agent: general-purpose
disable-model-invocation: true
---

Run a comprehensive dependency audit for the current project.

## Steps

1. Run `scripts/audit.sh <project-directory>` to generate a structured report
   - Example: `scripts/audit.sh /path/to/your/project`
   - If no directory is given, it defaults to the current working directory
   - The script covers: package.json check, security audit, outdated packages, unused dependency detection, and lock file health
   - It will NOT run `npm install`, `npm audit fix`, or modify any files

## Output Format

### Security Summary
| Severity | Count |
|----------|-------|
| Critical | N     |
| High     | N     |
| ...      | ...   |

Top issues: (list)

### Outdated Packages
- **Major updates available**: (list)
- **Minor/patch updates**: (count)

### Potentially Unused Dependencies
- (list or "None detected")

### Recommendations
Prioritized list of actions to take.

## Important
- Do NOT run `npm install` or modify any files
- Do NOT run `npm audit fix` — report only
- If a command fails, note it and continue with other checks
- Keep the report concise and actionable
