---
name: pr-review
description: >
  Review a GitHub pull request and post the findings back to the PR as inline
  comments. Resolves a PR by number, owner/repo#N, URL, or current branch;
  fetches the diff; runs code-reviewer, security-reviewer and a Codex lane in parallel;
  anchors each finding to a real diff line; previews; then posts ONE review
  with event=COMMENT. Never approves and never requests changes. Triggers:
  "/pr-review", "review PR 123", "review this pull request", "comment on the PR",
  "post review comments", "AI review my PR".
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Agent", "AskUserQuestion"]
argument-hint: "[PR ref] [focus hints] [--dry-run|--post]"
effort: high
---

# /pr-review — review a GitHub PR and post inline comments

A terminal review that **lands on the pull request**, not in a scroll buffer.
The review lane is Claude; the posting mechanics live in a deterministic script
so the JSON payload is never hand-built.

## Non-negotiable guardrails

1. **`event: "COMMENT"` always.** Never `APPROVE`, never `REQUEST_CHANGES`.
   Approval is a human decision (core-rules: no self-approval).
2. **Never dismiss, resolve, or reply to an existing review thread.**
3. **Repos the user does not own always get a confirmation before posting**, even
   when `--post` was passed. Owned = `<your-gh-user>`. Everything else — `<your-org>`,
   `<your-org>`, `HIG-Innovation Team`, any other org — is somebody else's PR.
4. **Never invent a line number.** Every inline anchor must exist in the diff.
   The script enforces this; do not work around it.
5. **Attribution:** the PR author's name comes from `gh`, never from memory.

## Step 1 — Resolve the PR

Parse `$ARGUMENTS`. The first token is the PR ref if it looks like one:

| Form | Example |
|---|---|
| bare number | `10178` (uses the repo in cwd) |
| slug + number | `<your-org>/<repo>#10178` |
| URL | `https://github.com/<your-org>/<repo>/pull/10178` |
| omitted | the open PR for the current branch |

Remaining words are focus hints (`security`, `error handling`, `tests`…). Flags
`--dry-run` and `--post` are consumed here, not passed to the reviewers.

If the ref is omitted and cwd has no PR, list candidates and ask which:

```bash
gh search prs --review-requested=@me --state=open --limit 10 \
  --json repository,number,title \
  --jq '.[] | "\(.repository.nameWithOwner)#\(.number)\t\(.title)"'
```

Then pull metadata:

```bash
gh pr view <N> --repo <slug> \
  --json number,title,author,headRefName,baseRefName,url,body,files,additions,deletions
```

## Step 2 — Fetch the diff

```bash
gh pr diff <N> --repo <slug> > "$SCRATCH/pr.diff"
```

Check the size first (`wc -l`). Rough guide:

- **under ~1500 lines** — hand the whole diff to both reviewers.
- **over that** — split by file into two roughly equal batches and give each
  reviewer the batch plus the full file list, so neither claims coverage it
  does not have. Say in the summary that the diff was split.

## Step 3 — Decide review depth

If `~/Repos/<repo>` exists, the reviewers may read surrounding source for real
context — tell them the checkout path. If it does not exist, this is a
**diff-only review**, and the review body must say so in one line. A diff-only
review cannot see callers, so do not assert "nothing else uses this".

Then fetch the repo's review rules from the PR's base branch (works for a
diff-only review too):

```bash
rm -f "$SCRATCH/REVIEW.md"
if B64=$(gh api "repos/<slug>/contents/REVIEW.md?ref=<baseRefName>" --jq .content 2>/dev/null); then
  printf '%s' "$B64" | base64 -d > "$SCRATCH/REVIEW.md"
fi
```

If it exists, it is the repo's own definition of what counts as Important, the
nit cap, and what not to report. Pass it to all three lanes (Step 4) and apply
it again when merging (Step 5). The summary says "Followed the repo's
REVIEW.md". No file means no change to the review. Write one with `/review-md`.

## Step 4 — Run the review lane

Two agents in parallel — the verbose-reviewer cap from core-rules. Both `model=`
the top tier (review is judgment work):

- `code-reviewer` — correctness, silent failures, missing tests, API misuse.
- `security-reviewer` — injection, authz, secrets, unsafe deserialization, PII.

Plus a third, independent lane: **Codex**, started via Bash (`run_in_background`)
at the same time as the two agents. It is paid for monthly and should run on
every review. Pipe the diff in and put the output contract below in the prompt:

```bash
codex exec -s read-only --skip-git-repo-check ${CHECKOUT:+-C "$CHECKOUT"} \
  -o "$SCRATCH/codex.json" \
  "Review this pull request diff (piped below) for correctness, silent failures, missing tests and security. <output contract>" \
  < "$SCRATCH/pr.diff"
```

`$CHECKOUT` is the `~/Repos/<repo>` path from Step 3, empty for a diff-only
review. If you cannot write files (the headless sweep), drop `-o` and read the
JSON from its stdout instead. If Codex fails, times out (cap it at 5 minutes) or
returns no parseable array, carry on with the two agents and say "Codex lane
failed" in the summary. Never block the review on it.

Fold any focus hints, and the REVIEW.md text if Step 3 found one, into all three prompts. Each prompt must end with this
output contract:

> Return a JSON array only. Max 10 findings, most severe first. No prose
> outside the array, no file dumps, no restating the diff. Schema per element:
> `{"path": "<repo-relative path exactly as it appears in the diff>",
> "line": <line number in the NEW version of the file>, "severity":
> "critical"|"important"|"suggestion", "problem": "<one sentence>", "fix":
> "<one sentence>"}`. Only report a finding you can point at a specific changed
> line for. If you have nothing, return `[]`.

## Step 5 — Merge

In the main thread, not in an agent:

- concatenate all three arrays (two if the Codex lane failed), drop exact duplicates on `path` + `line`
- when reviewers flag the same line differently, keep the higher severity
- if there is a REVIEW.md, drop anything it says not to report and apply its nit cap
- sort critical → important → suggestion
- write the merged array to `$SCRATCH/findings.json`

Also write `$SCRATCH/summary.md`: two or three sentences on what the PR does and
what the review found, then the counts by severity. No praise padding. If the
review was diff-only or the diff was split, say it here.

## Step 6 — Preview, confirm, post

Always dry-run first:

```bash
~/.claude/scripts/pr-review-post.sh \
  --pr <slug>#<N> \
  --findings "$SCRATCH/findings.json" \
  --summary  "$SCRATCH/summary.md"
```

The script reports how many findings anchored inline, how many fell back to the
summary, and how many were already posted on a previous run. Show the user the
severity counts and the target URL — not the whole payload.

Then decide:

- `--dry-run` was passed → stop here.
- Repo owner is `<your-gh-user>` **and** `--post` was passed → post.
- Anything else → `AskUserQuestion` with the PR title, author, and finding
  counts, offering post / dry-run-only / cancel.

To post, re-run the identical command with `--post` appended.

## Step 7 — Verify against live state

Never claim posted without checking:

```bash
gh api "repos/<slug>/pulls/<N>/comments" --jq 'length'
```

Confirm the count rose by the number of inline comments the script reported.
Report the PR URL and the counts. If the POST failed, quote the shortest
decisive line of the error — do not dump the payload.

## Re-running

Safe. The script reads existing review comments and skips any finding already
posted at the same path and line, so a re-review after a push adds only what is
new. It does not delete or supersede earlier comments.

## Known limits

- Anchors resolve to the **right-hand side** of the diff. A finding about
  deleted code has no anchor and lands in the summary section instead.
- GitHub rejects an entire review if one comment points at a line outside the
  diff. The script filters those out before posting; that is why findings
  sometimes appear in the body rather than inline.
- Azure DevOps is not supported. The equivalent there is
  `az devops invoke` against the pull-request threads API.
