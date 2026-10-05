---
name: review-md
description: Write a short REVIEW.md for a repo, telling code review what counts as Important, how many nits to post, what never to report and what to always check, built from the repo's own evidence (CLAUDE.md, CI, tests, past PR review comments). Read by /pr-review and by GitHub Code Review. Use when the user says "/review-md", "make a REVIEW.md", "review rules for this repo", "tune the reviews", "reviews are too noisy", or "REVIEW.md for everything I'm working on" (batch mode). Do NOT use to review a PR (that is pr-review), or to edit CLAUDE.md.
---

# /review-md: write a repo's review rules

REVIEW.md sits at the repo root. It is freeform markdown with review-only
instructions. Two things read it:

- **/pr-review** fetches it from the PR's base branch and passes it to every lane.
- **GitHub Code Review** (Anthropic's managed one, Team or Enterprise plans) reads it.

The local `/code-review` does NOT read it (Anthropic docs, code.claude.com/docs/en/code-review).
For that one, review rules have to go in CLAUDE.md. Say this once if the user asks why.

## Targets

- One repo: the current directory, or the repo the user names.
- Batch ("everything I'm working on"): every git repo under `~/Repos` with a commit
  in the last 14 days. List them first and say which you skipped and why
  (already has REVIEW.md, no remote, archived).

```bash
for d in ~/Repos/*/; do [ -d "$d/.git" ] || continue
  t=$(git -C "$d" log -1 --since="14 days ago" --format=%cs 2>/dev/null)
  [ -n "$t" ] && echo "$t ${d%/} $([ -f "$d/REVIEW.md" ] && echo HAS)"; done | sort -r
```

Batch over 3 repos: one subagent per repo, `model=sonnet`, max 3 at a time, each
returning the draft only.

## Step 1: gather evidence (read, do not guess)

Read the base branch, not the working tree (the checkout may be parked elsewhere):
`git -C REPO fetch -q && git -C REPO show origin/HEAD:PATH`.

1. CLAUDE.md, AGENTS.md, README: stated conventions, banned patterns.
2. CI config (`.github/workflows`, `azure-pipelines.yml`): what is already
   enforced by lint, typecheck or tests. Those never need a review comment.
3. Test layout and framework: what "missing test" means here.
4. Past review comments, the best signal of what people actually care about:
   ```bash
   SLUG=$(cd REPO && gh repo view --json nameWithOwner -q .nameWithOwner)
   gh api "repos/SLUG/pulls/comments?per_page=100" --jq '.[] | "\(.user.login): \(.body)"' | head -150
   ```
   Note what humans flagged repeatedly, and what bots flagged that got ignored.
5. Risky areas: auth, money, migrations or schema, PII, anything with "legacy" or
   "do not touch" in its docs.

## Step 2: write it (short beats complete)

Under 40 lines. A long REVIEW.md dilutes the rules that matter. Use these headings:

```markdown
# Review rules for REPO

## What Important means here
- (3 to 5 repo-specific bullets: data loss, auth bypass, money maths, schema change without migration...)

## Cap the nits
Report at most 5 nits per review. If there are more, say "plus N similar" in the summary.

## Do not report
- Anything CI already enforces: (name the linters, typecheck, formatter)
- (generated files, vendored code, lockfiles, paths that are out of scope)

## Always check
- (2 to 4 repo-specific checks drawn from past review comments)
```

Every bullet must trace to evidence from Step 1. If a section has no evidence,
leave it out rather than padding it with generic advice.

## Step 3: show, then write

Show the user the draft in a fenced markdown block, with one line per bullet saying
where it came from. Write the file only after he says yes. Never commit or push:
REVIEW.md is a repo change, and shared repos need his call (and a branch and PR).
In batch mode, show all drafts in one HTML artifact rather than a long reply.

## Common issues

- **Repo has no PR history**: skip step 4 and say the rules come from config only.
- **gh 404 on a repo you know exists**: another session may have switched the
  active gh account. Run `gh auth status` before concluding there's no access.
- **REVIEW.md already exists**: diff your draft against it and propose edits.
  Never overwrite it.
