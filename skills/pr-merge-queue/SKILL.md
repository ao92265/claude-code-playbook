---
name: pr-merge-queue
description: Batched PR merge loop with checkpoints. Use when triaging/merging open PR backlog across a repo. Triggers "merge queue", "pr backlog", "/pr-merge-queue", or autonomous ralph-style PR clearing sessions.
---

# PR Merge Queue

Process open PRs in batches with explicit pause/summary points. Designed to replace ad-hoc ralph loops that hit usage limits and wrong-branch commits.

## Protocol

1. **Enumerate.** `gh pr list --json number,title,headRefName,mergeable,isDraft,statusCheckRollup,reviewDecision`. Skip drafts.
2. **Batch size = 5.** Process 5 at a time, then STOP for summary.
3. **Per-PR steps:**
   - `git branch --show-current` — verify NOT on PR branch before any operation
   - Check CI status; if red and trivial (lint/type) → rebase + fix on PR branch only
   - If mergeable + approved → squash merge via `gh pr merge --squash --auto`
   - If conflicts → rebase onto main; if non-trivial, skip + log reason
   - **NEVER edit `prisma/schema.prisma`, migrations, or protected paths.** Flag + skip.
4. **Checkpoint after each batch:**
   - Post summary comment listing: merged / skipped+reason / blocked
   - Pause for user confirmation OR auto-resume only if explicitly authorized
5. **Stop conditions:**
   - Backlog cleared
   - 3 consecutive failures → stop + escalate
   - Protected-path PR encountered → stop + ask
   - Usage approaching limit → checkpoint summary + exit cleanly

## Verification

Before any `gh pr merge` or `git push`:
- Confirm target branch via `gh pr view <n> --json baseRefName`
- Confirm local branch != PR head (avoid accidental fixup commits to feature branch)

## Output

Final report: `[merged: N] [skipped: M reasons] [escalated: K reasons]`. One line per PR.
