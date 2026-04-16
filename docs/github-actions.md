---
title: GitHub Actions
nav_order: 2
parent: Advanced
---
# Claude Code in GitHub Actions

Automate code review, issue-to-PR workflows, and quality gates using Claude Code in your CI/CD pipeline.

---

## Overview

The official `anthropics/claude-code-action@v1` (GA as of early 2026) lets Claude Code run as a GitHub Action. It can review PRs, implement features from issues, generate tests, and produce reports — all triggered by events or `@claude` mentions in comments.

**Key capabilities:**
- Automated PR review on every push
- `@claude` trigger in any PR or issue comment for interactive work
- Issue-to-PR automation (Claude reads the issue, creates a full implementation PR)
- Scheduled reports (cron-triggered code health, dependency audits)
- AWS Bedrock and Google Vertex AI support for enterprise data residency

---

## Quick Start: Automated PR Review

The most common use case — Claude reviews every PR automatically.

```yaml
name: Claude Code Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Review this PR for:
            - Code quality and correctness
            - Security vulnerabilities (OWASP Top 10)
            - Breaking changes to public APIs
            Post findings as inline review comments.
          claude_args: "--max-turns 5 --model claude-sonnet-4-6"
```

---

## Interactive: @claude in Comments

Let team members ask Claude to do work directly in PRs and issues.

```yaml
name: Claude Interactive
on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  claude:
    if: contains(github.event.comment.body, '@claude')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      issues: write
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          claude_args: "--max-turns 10 --model claude-sonnet-4-6"
```

**Usage examples in comments:**
- `@claude implement this feature` — Claude reads the issue/PR description and pushes code
- `@claude fix the failing tests` — Claude diagnoses and fixes test failures
- `@claude add tests for the new validation logic` — Claude generates targeted tests
- `@claude explain what this PR does` — Claude summarises changes for reviewers

---

## Issue-to-PR Automation

Claude reads an issue, implements the feature, and opens a PR.

```yaml
name: Claude Issue Resolver
on:
  issues:
    types: [labeled]

jobs:
  implement:
    if: github.event.label.name == 'claude-implement'
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      issues: write
    steps:
      - uses: actions/checkout@v4

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Read issue #${{ github.event.issue.number }}.
            Implement the requested feature.
            Create a PR with the implementation.
            Include tests.
          claude_args: "--max-turns 20 --model claude-sonnet-4-6"
```

**Workflow:** Label an issue with `claude-implement` → Claude creates a branch, implements the feature, opens a PR linking the issue.

---

## Scheduled Reports

Run Claude on a schedule for recurring analysis.

```yaml
name: Weekly Code Health
on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9am

jobs:
  report:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      issues: write
    steps:
      - uses: actions/checkout@v4

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Analyse the codebase and create a GitHub issue titled
            "Weekly Code Health Report - $(date +%Y-%m-%d)" covering:
            - Dependencies with known vulnerabilities
            - Code quality hotspots
            - Test coverage gaps
            - Stale TODOs older than 30 days
          claude_args: "--max-turns 15 --model claude-sonnet-4-6"
```

---

## Enterprise: AWS Bedrock

Route through AWS Bedrock for data residency and compliance. Uses OIDC — no static API keys.

```yaml
name: Claude Review (Bedrock)
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      id-token: write  # Required for OIDC
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/claude-ci-role
          aws-region: us-east-1

      - uses: anthropics/claude-code-action@v1
        with:
          use_bedrock: "true"
          claude_args: "--model us.anthropic.claude-sonnet-4-6 --max-turns 5"
```

---

## Enterprise: Google Vertex AI

Route through Vertex AI with Workload Identity Federation.

```yaml
name: Claude Review (Vertex)
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      id-token: write
    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123456/locations/global/workloadIdentityPools/ci-pool/providers/github
          service_account: claude-ci@project.iam.gserviceaccount.com

      - uses: anthropics/claude-code-action@v1
        with:
          use_vertex: "true"
          claude_args: "--model claude-sonnet-4-6 --max-turns 5"
```

---

## Using CLAUDE.md in CI

The action respects your project's `CLAUDE.md` file. Add CI-specific instructions:

```markdown
## CI/CD Rules

When running in GitHub Actions:
- Never modify package-lock.json or yarn.lock
- Always run existing tests after making changes
- Prefer minimal, focused changes over sweeping refactors
- Post review comments on specific lines, not as general comments
```

---

## Migration from Beta

If you used the beta version of `claude-code-action`, these parameters changed in v1.0:

| Beta Parameter | v1.0 Replacement |
|:---------------|:-----------------|
| `direct_prompt` | `prompt` |
| `mode` | Removed — use `claude_args` with `--max-turns` |
| `max_turns` | `claude_args: "--max-turns N"` |
| `model` | `claude_args: "--model model-id"` |
| `custom_instructions` | `prompt` (inline) or `CLAUDE.md` (persistent) |

---

## Cost Considerations

| Workflow | Typical Token Usage | Approx. Cost (Sonnet) |
|:---------|:------------------:|:---------------------:|
| PR review (small) | 10K-30K | $0.05-0.15 |
| PR review (large) | 30K-100K | $0.15-0.50 |
| Issue implementation | 50K-200K | $0.25-1.00 |
| Scheduled report | 30K-80K | $0.15-0.40 |

**Budget tip:** Set `--max-turns` to limit how much work Claude does per run. Start with 5 for reviews, 10-20 for implementations.

---

## Security Best Practices

1. **Store API keys as GitHub Secrets** — never hardcode in workflow files
2. **Use OIDC for cloud providers** — Bedrock and Vertex support keyless auth
3. **Limit permissions** — only grant `contents: write` when Claude needs to push code
4. **Set max-turns** — prevents runaway sessions that burn tokens
5. **Review Claude's PRs** — treat AI-generated PRs the same as human PRs
6. **Restrict `@claude` triggers** — consider limiting to team members via `if` conditions
