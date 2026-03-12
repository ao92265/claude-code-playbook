---
name: pr-batch-review
description: >
  Batch review and manage multiple open PRs in one pass. Lists all open PRs, checks CI
  status, reviews diffs, and provides a consolidated report with merge recommendations.
  Triggers: "review all PRs", "batch PR review", "check my PRs", "PR status".
metadata:
  user-invocable: true
  slash-command: /pr-batch-review
  proactive: false
---

# PR Batch Review

Review and manage multiple open PRs in a single consolidated pass.

## Steps

1. Verify git credentials work:
   - `gh auth status`
   - If credentials fail, STOP and report — do not proceed

2. List all open PRs:
   - `gh pr list --state open`
   - Show count and titles

3. For each PR (limit to 6 max to avoid rate limits):
   - Check CI status: `gh pr checks <number>`
   - Review diff: `gh pr diff <number>`
   - Note any issues: failing tests, security concerns, style problems

4. Present a consolidated summary table:
   | PR # | Title | CI Status | Issues Found | Recommendation |
   |------|-------|-----------|--------------|----------------|

5. **STOP and ask which PRs to merge** — do not auto-merge anything

## Important
- Do NOT merge any PR without explicit user approval
- Do NOT spawn more than 3 parallel agents for PR reviews
- If a PR has failing checks, recommend investigating before merging
- Flag any PRs with security-sensitive changes for closer review
