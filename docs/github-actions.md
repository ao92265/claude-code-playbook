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

## Auth: OAuth Token vs API Key

You have two ways to authenticate the action. Pick based on cost model.

| Auth method | Secret | Bills against | When to use |
|:------------|:-------|:--------------|:------------|
| **OAuth token** | `CLAUDE_CODE_OAUTH_TOKEN` | Your Claude Max subscription | If you have Max — no extra token spend |
| **API key** | `ANTHROPIC_API_KEY` | Anthropic API account | Pay-per-token, no Max sub |

**Generate the OAuth token:**
```bash
claude setup-token
```
Drop the resulting token into your repo secrets as `CLAUDE_CODE_OAUTH_TOKEN`. The action picks the right credential based on which secret is wired into the workflow.

**Cost reality:** OAuth ≠ free. It consumes your Max usage budget. Heavy auto-review across many repos can throttle your local Claude Code sessions. Watch the first week before scaling to more repos.

---

## One-Command Install

Run this inside any repo from the Claude Code CLI:

```bash
claude /install-github-app
```

It walks you through:
1. Installing the Anthropic GitHub App on the org/repo
2. Choosing OAuth (Max) vs API key auth
3. Writing `claude.yml` (interactive) and `claude-code-review.yml` (auto-review) into `.github/workflows/`
4. Setting the secret on the repo

**Important caveats** (learned the hard way — see [Real-World Gotchas](#real-world-gotchas) below):
- The auto-installed `claude-code-review.yml` ships with `pull-requests: read` permission. Claude can read the PR but **cannot post comments**. You must change it to `write`.
- `/install-github-app` commits directly to the default branch. There is no PR. If your repo has branch protection on `main`, run it on a fork or temporarily relax protection.
- The Anthropic GitHub App validates that the workflow file on a PR **matches the default branch exactly**. Edits to the workflow file on a feature branch fail with `401 Unauthorized — Workflow validation failed`. Always merge workflow changes to `main` first.

---

## Quick Start: Automated PR Review

The most common use case — Claude reviews every PR automatically.

```yaml
name: Claude Code Review
on:
  pull_request:
    types: [opened, synchronize, ready_for_review]
    paths:
      - 'src/**'
      - '!**/*.md'
      - '!**/generated/**'

jobs:
  review:
    if: |
      github.event.pull_request.draft == false &&
      github.actor != 'dependabot[bot]' &&
      github.actor != 'github-actions[bot]'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: |
            Review this PR with radical candor against project standards in CLAUDE.md.
            Focus on:
            - Logic correctness and edge cases
            - Security (OWASP Top 10, injection, authz)
            - Breaking changes to public APIs
            - Test coverage for new code
            REQUEST_CHANGES on anything actionable. APPROVE only when fully clean.
            Post inline comments with file:line and a top-level summary.
```

**Why these defaults matter:**
- `paths:` filter prevents review on doc-only / generated changes — saves tokens
- `draft == false` avoids reviewing work-in-progress drafts
- `dependabot[bot]` skip avoids reviewing every dep bump
- `pull-requests: write` + `issues: write` are required to actually post — the auto-installed default has these as `read` and silently fails to post

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

## Real-World Gotchas

Lessons from rolling auto PR review onto a real production repo (NestJS + React + Prisma):

**1. Default workflow permissions block posting.**
The `claude-code-review.yml` written by `/install-github-app` ships with `pull-requests: read`, `issues: read`. The action runs to completion, the run goes green, and **nothing gets posted**. The action has no permission to write comments. Change to `write` for both. Symptom in logs: action exits cleanly, no errors, zero comments on the PR.

**2. Workflow file must match the default branch exactly.**
The Anthropic GitHub App validates the workflow file on every PR against the version on the default branch. If they differ — even a one-line perms change on a feature branch — token exchange fails with:
```
App token exchange failed: 401 Unauthorized
Workflow validation failed. The workflow file must exist and have
identical content to the version on the repository's default branch.
```
**Implication:** you cannot test workflow edits on a PR. Workflow changes have to land on `main` first, then take effect on the next PR.

**3. `issue_comment` events run from the default branch.**
The `@claude` mention workflow uses `on: issue_comment`. GitHub runs `issue_comment`-triggered workflows from the default branch's copy of the file, not the PR's copy. So even if you fix the workflow on a feature branch, `@claude` mentions still use the broken main-branch version until it merges.

**4. The action auto-checks-out the PR.**
You don't strictly need `actions/checkout@v4` as a separate step — the action does an internal checkout. But adding it explicitly is harmless and makes the workflow easier to read.

**5. Path filters are critical for cost control.**
Without `paths:`, every doc/config/lockfile PR triggers a full review. On a busy repo this burns Max quota fast. Filter aggressively. Add `!**/generated/**`, `!**/*.md`, `!**/*.lock` exclusions.

**6. Two parallel runs per `@claude` mention is normal.**
The action sometimes spawns a duplicate run for the same comment. One succeeds, one fails the internal checkout race. The successful one posts. Don't chase the failures.

**7. Max quota throttling cuts both ways.**
Auto-review consumes the same Max budget as your local Claude Code sessions. Heavy auto-review on a busy repo will throttle your interactive work. Pilot on one repo first, watch usage for a week, then scale.

**8. Branch protection blocks `/install-github-app`.**
The CLI command pushes directly to the default branch. If `main` is protected, the push fails. Run on a fresh branch or temporarily relax protection.

---

## Security Best Practices

1. **Store API keys as GitHub Secrets** — never hardcode in workflow files
2. **Use OIDC for cloud providers** — Bedrock and Vertex support keyless auth
3. **Limit permissions** — only grant `contents: write` when Claude needs to push code
4. **Set max-turns** — prevents runaway sessions that burn tokens
5. **Review Claude's PRs** — treat AI-generated PRs the same as human PRs
6. **Restrict `@claude` triggers** — consider limiting to team members via `if` conditions
