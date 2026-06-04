---
name: pr-fleet
description: Overnight parallel PR processing via subagent fleet + git worktrees. Coordinator triages backlog, spawns one worker per PR (capped at 3 concurrent), only escalates protected-path or non-trivial conflicts to user. Triggers "/pr-fleet", "overnight pr fleet", "parallel pr merge". Do NOT use for: a single PR (merge it directly), non-GitHub repos, or when you need interactive per-PR review rather than autonomous clearing.
---

# PR Fleet — Parallel Overnight PR Orchestrator

Replaces sequential ralph-loop merges with concurrent subagent workers. One coordinator + N parallel workers per PR via git worktrees.

## When to invoke

- Overnight batch clearing of PR backlog
- Schedulable via cron through `claude -p "/pr-fleet"` headless mode
- Repo has open PR queue (>3 PRs makes parallelism worthwhile)

## Shared State

`.omc/state/pr-swarm.json` (per-repo) tracks every PR in the run:

```json
{ "prs": { "8669": { "status": "in_progress", "claimed_by": "worker-2", "attempts": 1, "blocker_reason": null } } }
```

Statuses: `pending | in_progress | done | blocked`. Atomic claim/release via `state-helpers.sh` (mkdir-mutex lock). Workers MUST claim before acting; if claim returns non-zero, skip to next PR.

## Coordinator Protocol

### Step 0 — Pre-flight (REQUIRED)

Run `bash ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/pr-fleet/state-helpers.sh preflight`. Hard-fails on missing `gh`/`jq`, unauthenticated gh, or `git fetch` failure.

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

Coordinator calls `state-helpers.sh init <pr#> <pr#>...` once, then spawns `Agent` subagents (subagent_type=`executor`, model=`sonnet`) with this worker prompt:

```
PR #<N>: <title>
Base: <baseRefName>  Head: <headRefName>
Worker-id: <unique-id>

Steps:
1. Claim: bash ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/pr-fleet/state-helpers.sh claim <N> <worker-id>
   - exit 1 → another worker has it; pick next PR
2. Create worktree: git worktree add ../wt-pr-<N> origin/<headRefName>
3. cd into worktree, install deps if needed (npm ci)
4. Rebase onto origin/<baseRefName>; if non-trivial conflict → block "<reason>" + skip
5. Run: tsc -b && npm test && npm run lint
6. If failures trivial (lint auto-fixable, type mismatch in your PR's files only) — fix + commit "ci: auto-fix"
7. If failures persist → block "<paste 30 lines>" + skip
8. If green → push to origin/<headRefName>, gh pr merge <N> --squash --auto
9. Cleanup: cd back, git worktree remove ../wt-pr-<N>
10. Mark done: bash ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/pr-fleet/state-helpers.sh done <N>
11. Return one line: PR-<N>: MERGED | BLOCKED-<reason>

On any hook/firewall block: state-helpers.sh block <N> "<reason>" + exit cleanly. NEVER stall waiting for human.

HARD RULES:
- NEVER edit prisma/schema.prisma, migrations/**, or .github/workflows/**
- NEVER push --force, --no-verify, or bypass hooks
- NEVER touch files outside this PR's diff
- Use tsc -b (NOT --noEmit) — CI parity
```

Wait for all subagents (cap 3 concurrent — batch the rest).

### Step 3 — Synthesize

Run `bash ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/pr-fleet/state-helpers.sh report` for the per-status roll-up.

Distinguish three exit buckets:
- `done` — merged cleanly
- `needs_human_decision` — worker reported BLOCKED with non-environmental reason (conflict, review pending, CI red on legit failure)
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

### Step 4 — Exit cleanly

- `git worktree prune` to remove any orphan worktrees
- DO NOT cancel any active OMC mode; coordinator exits naturally

## Hard Rules (coordinator)

- Max 3 concurrent subagents (CC quota)
- Max 20 PRs per run (chunk larger backlogs)
- Stop if 3 consecutive workers report FAILED — likely systemic issue
- Never approve or self-merge own PRs (authorship check via `gh pr view <n> --json author`)
- Headless mode (`claude -p`): no interactive prompts; escalations go to log only

## Headless invocation

```bash
~/.claude/scripts/pr-fleet.sh <repo-path>
```

See script for cron setup.
