---
disable-model-invocation: true
name: pr-fleet
description: Parallel PR processing via subagent fleet + git worktrees, autonomous overnight (default) or interactive batched with user checkpoints (--interactive flag). Coordinator triages backlog, spawns one worker per PR (capped at 3 concurrent), only escalates protected-path or non-trivial conflicts to user. Triggers "/pr-fleet", "overnight pr fleet", "parallel pr merge", "merge queue", "pr backlog", "/pr-merge-queue". Do NOT use for: a single PR (merge it directly) or non-GitHub repos.
---

# PR Fleet — Parallel PR Orchestrator

Replaces sequential ralph-loop merges with concurrent subagent workers. One coordinator + N parallel workers per PR via git worktrees. Runs in two modes (see below).

## When to invoke

- Batch clearing of PR backlog, overnight or interactive
- Schedulable via cron through `claude -p "/pr-fleet"` headless mode (autonomous mode only)
- Repo has open PR queue (>3 PRs makes parallelism worthwhile)

## Modes

- **Autonomous (default).** Unattended overnight run. Dispatches the whole queue (chunked to the 20-PR cap), never merges, writes a morning report for the human to action. No pauses.
- **Interactive (`--interactive`, or triggered by "merge queue" / "pr backlog" / "/pr-merge-queue").** Same triage + worker protocol, but processes in batches of 5 with a checkpoint after each batch: post a summary, pause for user confirmation, and only then merge the confirmed PRs. Use this when the user wants to stay in the loop rather than wake up to a fait accompli. See Step 3a.

## Shared State

`.omc/state/pr-swarm.json` (per-repo) tracks every PR in the run:

```json
{ "prs": { "8669": { "status": "in_progress", "claimed_by": "worker-2", "attempts": 1, "blocker_reason": null } } }
```

Statuses: `pending | in_progress | done | blocked`. Atomic claim/release via `state-helpers.sh` (mkdir-mutex lock). Workers MUST claim before acting; if claim returns non-zero, skip to next PR.

## Coordinator Protocol

### Step 0 — Pre-flight (REQUIRED)

Run `bash ~/.claude/skills/pr-fleet/state-helpers.sh preflight`. Hard-fails on missing `gh`/`jq`, unauthenticated gh, or `git fetch` failure.

Additionally:
- If any queued PR touches `prisma/**` or `.github/workflows/**`, set `OMC_SKIP_HOOKS=protect-paths` for the run AND surface to user before dispatch.
- Verify `git push --dry-run --force-with-lease` against an arbitrary head returns no firewall block.

If pre-flight fails: STOP. Do not dispatch — workers will all stall on the same blocker.

### Step 1 — Triage

```bash
gh pr list --state open --json number,title,headRefName,baseRefName,mergeable,isDraft,statusCheckRollup,reviewDecision,files \
  --limit 50
```

Filter:
- SKIP drafts
- SKIP PRs touching `prisma/schema.prisma`, `migrations/**`, `.github/workflows/**`, or any protect-paths target → add to ESCALATIONS list
- SKIP PRs with reviewDecision=`CHANGES_REQUESTED` → add to BLOCKED list
- QUEUE remainder

### Step 2 — Dispatch (parallel, cap 3 concurrent)

- **Autonomous mode:** dispatch the full queue in waves of 3 concurrent, no pause between waves.
- **Interactive mode:** dispatch in batches of 5 PRs (still capped at 3 concurrent within the batch); after each batch of 5 finishes, stop and run Step 3a before dispatching the next batch.

Coordinator calls `state-helpers.sh init <pr#> <pr#>...` once, then spawns `Agent` subagents (subagent_type=`executor`, model=`sonnet`) with this worker prompt:

```
PR #<N>: <title>
Base: <baseRefName>  Head: <headRefName>
Worker-id: <unique-id>

Steps:
1. Claim: bash ~/.claude/skills/pr-fleet/state-helpers.sh claim <N> <worker-id>
   - exit 1 → another worker has it; pick next PR
2. Create worktree: git worktree add ../wt-pr-<N> origin/<headRefName>
3. cd into worktree, install deps if needed (npm ci)
4. Rebase onto origin/<baseRefName>; if non-trivial conflict → block "<reason>" + skip
5. Run: tsc -b && npm test && npm run lint
6. If failures trivial (lint auto-fixable, type mismatch in your PR's files only) — fix + commit "ci: auto-fix"
7. If failures persist → block "<paste 30 lines>" + skip
8. PRE-MERGE LIVE RE-VERIFY (never trust triage-time state — it goes stale):
   gh pr view <N> --json reviewDecision,statusCheckRollup,mergeable
   - reviewDecision == CHANGES_REQUESTED → block "CHANGES_REQUESTED still live (sticky until the reviewer dismisses)" + skip. NEVER dismiss a reviewer's review.
   - any required check != SUCCESS, or mergeable != MERGEABLE → block "not green/mergeable: <paste>" + skip
9. If clean → push to origin/<headRefName> ONLY. Do NOT merge. (Verify-first: the human merges from the morning report. No `gh pr merge`, no `--auto`.)
10. Cleanup: cd back, git worktree remove ../wt-pr-<N>
11. Mark done: bash ~/.claude/skills/pr-fleet/state-helpers.sh done <N>
12. Return one line: PR-<N>: READY-TO-MERGE | BLOCKED-<reason>

On any hook/firewall block: state-helpers.sh block <N> "<reason>" + exit cleanly. NEVER stall waiting for human.

HARD RULES:
- NEVER edit prisma/schema.prisma, migrations/**, or .github/workflows/**
- NEVER push --force, --no-verify, or bypass hooks
- NEVER merge a PR or dismiss a review — push + report READY-TO-MERGE only; the human merges
- NEVER touch files outside this PR's diff
- Use tsc -b (NOT --noEmit) — CI parity
```

Wait for all subagents (cap 3 concurrent — batch the rest).

### Step 3 — Synthesize

Run `bash ~/.claude/skills/pr-fleet/state-helpers.sh report` for the per-status roll-up.

Distinguish three exit buckets:
- `ready` — pushed, CI green + review clear (re-verified live), awaiting YOUR merge. List these first with the one-line `gh pr merge <N> --squash` command so the human can merge in seconds.
- `needs_human_decision` — worker reported BLOCKED with non-environmental reason (conflict, CHANGES_REQUESTED still live, CI red on legit failure)
- `environmental_blocker` — hook/firewall/auth blocker; reproducible mechanical fix



Compose morning report:

```
PR FLEET RUN <timestamp>
================
MERGED (<count>):
  - PR-<n>: <title>
  - ...

SKIPPED (<count>) — re-run candidates:
  - PR-<n>: <reason>
  - ...

FAILED (<count>) — needs human:
  - PR-<n>: <reason summary>

ESCALATIONS (<count>) — protected-path, user auth required:
  - PR-<n>: touches <paths>

BLOCKED (<count>) — changes-requested:
  - PR-<n>: awaiting author
```

Write to `~/logs/pr-fleet-$(date +%F-%H%M).log`.

Interactive mode: skip the morning-report format above and use Step 3a's checkpoint report instead.

### Step 3a — Interactive Checkpoint (interactive mode only)

After each batch of 5 (or when the queue runs out, whichever is first):

1. Post a checkpoint summary: `[merged: N] [skipped: M reasons] [escalated: K reasons]` — one line per PR, reason inline for skipped/escalated.
2. **Pause for user confirmation.** Do not dispatch the next batch or merge anything until the user responds, unless the user pre-authorized the whole run to auto-resume batch-to-batch at the start of the session — in that case still post the summary, just don't block on it.
3. On confirmation, merge the confirmed-ready PRs: for each, re-confirm target branch (`gh pr view <n> --json baseRefName`) and that the coordinator's local checkout is not sitting on the PR's head branch, then `gh pr merge <n> --squash`. This is the one place interactive mode differs from autonomous mode — autonomous never merges (push-only, human merges from the log); interactive merges live at the checkpoint once the user says go.
4. Stop conditions (in addition to the Hard Rules below): backlog cleared; protected-path PR encountered → stop and ask (don't just log it to ESCALATIONS and continue); usage approaching limit → post the checkpoint summary and exit cleanly rather than starting another batch.

### Step 4 — Exit cleanly

- `git worktree prune` to remove any orphan worktrees
- DO NOT cancel any active OMC mode; coordinator exits naturally

## Hard Rules (coordinator)

- Max 3 concurrent subagents (CC quota)
- Max 20 PRs per run (chunk larger backlogs)
- Stop if 3 consecutive workers report FAILED — likely systemic issue
- Never approve or self-merge own PRs (authorship check via `gh pr view <n> --json author`)
- Headless mode (`claude -p`): no interactive prompts; escalations go to log only. (Interactive mode is never run headless — checkpoints require a live user.)

## Headless invocation

```bash
~/.claude/scripts/pr-fleet.sh <repo-path>
```

See script for cron setup.
