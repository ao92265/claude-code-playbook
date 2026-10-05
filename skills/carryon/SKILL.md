---
disable-model-invocation: true
name: carryon
description: >
  Unattended continuation. Reconstructs where the work actually is, picks the single
  highest-value next action from a fixed priority ladder, does it, verifies it, ships it,
  and repeats — without needing you to read anything in between. Full send: commits,
  pushes, opens PRs. Stops only on a blocker, a decision only you can make, an
  irreversible op, or when there is genuinely nothing left. Hands back a 3-line verdict;
  full trail goes to a log file.

  Triggers: "/carryon", "carry on", "keep going", "crack on", "just continue",
  "next best action", "keep it moving", "I don't have time to read this".

  Do NOT use for: a task you have not started yet (state the task instead), anything
  needing a product/design decision, or work you intend to review step-by-step.
metadata:
  user-invocable: true
  slash-command: /carryon
  proactive: false
---

# carryon — pick the best next action, do it, repeat

You are running unattended. the user is not reading the output. Every turn must end with
the work further along, not with a question he has to answer.

Flags: `--once` (one action then stop) · `--dry` (name the pick, do nothing) ·
`--no-push` (local + commit only, this run).

## 1. Orient (cheap, once per run — do not re-do each iteration)

Run in parallel, read only what you need:

- `git status --short --branch` and `git log --oneline -10`
- `gh pr list --author @me --json number,title,reviewDecision,statusCheckRollup` (if a remote exists)
- Latest `.omc/handoffs/*` or `~/.claude/reboots/*` for this cwd, if present
- Any in-flight task list, plan file (`.omc/plans/`), or TODO left by this session

**Assert location before the first edit.** Confirm `git branch --show-current` is the
intended branch. Mismatch → fix location first, never edit past it. If on the default
branch, branch before editing.

## 2. Pick ONE action — fixed ladder, top match wins

Walk the ladder in order. Take the first rung that has a real candidate. Do not
skip up. Do not batch rungs.

1. **Broken beats new.** Failing build, typecheck, lint, or test on the current
   branch → fix that. Nothing else matters while red.
2. **Unblock beats build.** Something another person or a queued job is waiting on
   (review comment to address, CI failure on an open PR, merge conflict).
3. **Finish beats start.** In-flight incomplete work: uncommitted diff, half-written
   function, a stub, a `TODO` this session left, a `test.skip`. Placeholders are
   blockers, not progress — implement or report them.
4. **Verify beats claim.** A change asserted done but never actually driven → exercise
   the real flow (`verify` skill), not just green tests. Tests-pass ≠ works.
5. **Ship beats polish.** Verified, committed work sitting unpushed → push it; pushed
   branch with no PR → open one.
6. **Then, and only then, next planned item** from the plan/task list/handoff.
7. **Nothing on the ladder → STOP.** Report "nothing left". Do not invent work.

Rung 7 is the point of this skill. Inventing plausible-looking busywork is the
failure mode — refactors nobody asked for, speculative tests, defensive rewrites.
If you cannot name which rung the action came from, it is not an action.

## 3. Do it

- Edit-heavy or multi-file → delegate to `executor` (`model=sonnet`; `opus` for
  judgment work). Prompt every subagent: "return verdict + max 5 bullets, no full body".
- 2+ file edits → failing test or explicit assertion checklist BEFORE editing.
- External dependency (SSO, OAuth, third-party API, MDM, browser auth) → run the
  feasibility probe and name the fallback BEFORE building anything on it. No probe,
  no build.
- Two failed fix passes on the same problem → hand to `/codex:rescue`, don't grind.

## 4. Verify, then ship

Gate every action before it counts as done:

1. `/done` — typecheck + lint + tests + build. Non-zero exit = not done, back to rung 1.
2. `verify` skill — drive the actual change and observe it. Required for anything
   with a runtime surface.
3. Commit on the working branch. Push. **Push-verify:** confirm
   `git branch --show-current` matches the target, then confirm `git push` exited 0
   AND the output is not `up-to-date` / rejected before claiming pushed.
4. Branch has commits and no PR → open one.

Append one line per action to `.omc/carryon/run-<timestamp>.md` (or the scratchpad
dir if not in a repo): rung, action, verify command, exit code.

## 5. Loop or stop

Loop back to step 2 unless `--once`. **Stop immediately** on any of:

- Ladder empty (rung 7)
- Same action failed twice
- Needs a decision only the user can make — product/design choice, ambiguous requirement,
  which-of-two-approaches, a credential you don't have
- **Irreversible or outward-facing:** deploy, prod, DB migration/schema change,
  force-push, `rm` of anything untracked, dismissing a reviewer's active
  CHANGES_REQUESTED, sending anything to a person. Stop and ask. Full send covers
  push and PR — it does not cover these.
- Schema/protected paths (`.env*`, lockfiles, credentials) needed
- 20 tool calls or ~50% context, whichever first → write a `/reboot` handoff, then stop
- 15 minutes stuck with no forward progress
- 4h wall-clock, self-enforced. Run Referee pauses the run at the same mark if you do not,
  but treat that as the backstop, not the control.

## 6. Report — 3 lines, no more

```
DID:     <what changed> (<n> actions, rungs <x,y>)
GREEN:   <verify command> exit 0 · <PR #n | branch pushed | local only>
NEXT:    <the rung-N action waiting> | STOPPED: <reason, and what you need from me>
```

Everything else goes in the log file. Name the log path on a fourth line only if
something failed. No summary tables, no per-file narration, no "let me know if".

If the stop reason is just "needs more iterations", say so and hand back a
ready-to-paste `/loop` or `/goal` line instead of asking a question.

## Hard rules

- Never claim done without a pasted verify command and exit code.
- Never self-approve. Review/verification is a separate pass (`code-reviewer`,
  `verifier`), never the same context that wrote the code.
- Never certify a UI or theme change from your own screenshots — root-cause it in
  source, then ask the user to confirm in his browser.
- `RESEARCH-ONLY` in scope → findings only, no edits, ladder rungs 1–6 do not apply.
