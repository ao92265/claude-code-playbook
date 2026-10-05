---
disable-model-invocation: true
name: oneshot
description: >
  One-shot, fully-autonomous kitchen-sink pipeline: research -> deep PRD -> consensus
  plan -> autonomous build -> QA loop -> paid code review -> CI gate -> PR opened + green.
  Throws the whole stack (prdforge, consensus agents, ralph, done, demo-qa, codex review)
  at one idea with zero interrupts, stating assumptions in the PRD instead of asking.
  Triggers "/oneshot", "oneshot", "one shot one kill", "kitchen sink", "throw everything at it",
  "full pipeline", "idea to PR". Flags --deep (default) / --balanced / --quick / --no-pr / --deploy.
  Do NOT use for one-line fixes, lookups, trivial edits, or when the user wants code written
  immediately with no plan (just write it). Not for deploy-only or PR-review-only tasks.
metadata:
  user-invocable: true
  slash-command: /oneshot
  proactive: false
---

# oneshot

Fire the entire build pipeline from a single prompt and walk away. `/oneshot "build X"`
chains research -> deep PRD -> consensus plan -> autonomous build -> QA loop -> paid
review -> CI gate -> PR, with **zero interrupts**. Assumptions and open questions get
written into the PRD, never asked. Stops at a reviewed, green PR — deploy stays a
separate manual gated step.

This skill is the orchestrator only. It does no building itself; it sequences existing
skills and hands each artifact to the next. Most handoffs self-wire because the
downstream skills already detect upstream artifacts (ralph skips its own PRD scaffold
when the Phase 3 consensus plan exists).

## When to invoke

- Non-trivial feature/build work where you want the full stack run end to end unattended.
- You said "oneshot", "one shot one kill", "kitchen sink", "throw everything at it",
  "full pipeline", or "idea to PR".

## When NOT to invoke

- One-line fixes, lookups, trivial edits — just write the code, skip the pipeline.
- User wants code written immediately with no plan.
- Deploy-only or review-only tasks (use `deploy` or `code-review` directly).

## Pipeline phases

Run these in order. Each phase gates the next; on a hard failure, loop back to the
named phase (bounded) rather than pushing forward.

### Phase 0 — Bootstrap
- Plant the canary tripwire: instruct yourself to begin every reply with the canary
  marker for the duration of the run. If it silently drops later, context is rotting —
  `/clear` + bootstrap from handoff instead of pushing through.
- **Size the task.** Trivial (one-liner / lookup / single-file edit) -> bail out, tell
  the user to just ask for the code directly; oneshot is for non-trivial work.
- Record start time for the 4h cap and the 15-min-stuck self-cancel rule.
- Record the run in `.omc/state/oneshot-state.json` (start time, phase, target) so a
  resumed session can tell whether a run is still live.

### Phase 1 — Research  (haiku/sonnet, max 3 parallel)
- Fan out `Explore` agents to gather repo context; use the `context7` MCP for external
  SDK/framework docs (repo docs first, web fallback). Cap
  at 3 concurrent, 2 for verbose lanes. Always pass each agent an explicit `model`.
- Cap subagent output: "return findings + max 5 bullets, no full body".
- Write findings to `.omc/research/oneshot-{slug}.md`.

### Phase 2 — Deep PRD  ->  `Skill(prdforge)`
- Run `prdforge` at the depth set by the flag (default deep = 6 personas + critic).
  Fully autonomous; it states assumptions in the PRD.
- Output: `.omc/plans/{slug}-prd.html`, `.omc/plans/{slug}-prompt.md`, `.omc/plans/{slug}-prd.json`.

### Phase 3 — Consensus pass  (agents, no pause)
- Take the prdforge plan from Phase 2 and run it through a Planner -> Architect -> Critic
  loop as agents: `Task(subagent_type="planner")`, `Task(subagent_type="architect")`,
  `Task(subagent_type="critic")`. Up to 5 iterations, no pause.
- Output: `.omc/plans/consensus-{slug}.md`. Because oneshot is fully autonomous, **treat the
  consensus sign-off as the approval and proceed** — do not stop for the user.
- `--quick` skips this phase entirely.

### Phase 4 — Build  ->  `Skill(ralph)`
- Feed ralph the Phase 3 consensus plan as its PRD input so it skips its own scaffold
  generation. Ralph persists story-by-story until every acceptance criterion passes and a
  separate reviewer signs off. `--balanced` = single ralph pass, no re-iteration.
- **Protected paths** (`prisma/schema.prisma`, migrations): STOP, surface for explicit
  auth, never bypass the protect-paths hook.

### Phase 5 — QA loop  ->  `Skill(done)` then `Skill(demo-qa)`
- `done` cycles tests/build/lint/typecheck; on failure spawn architect-diagnose then
  executor-fix; max 5 cycles; early exit on 3 identical failures.
- Anything with a UI or runtime surface additionally goes through `demo-qa` — root-cause in
  source, never a screenshot patch. Green tests are not evidence the thing works.

### Phase 6 — Review gate  (paid, SEPARATE lane — never self-approve)
- `/codex:rescue` on the diff for any non-trivial change.
- High-stakes change (security / prod / irreversible — auto-detect from the diff):
  escalate to `/multiask`.
- Run a separate `verifier` or `code-reviewer` pass.
  The build agent never approves its own work in the same context.
- Any prose artifact (README, PR body): run the `anti-ai-prose` skill before it ships.
- Feed confirmed findings back to Phase 4 and re-verify.

### Phase 7 — CI gate  ->  `Skill(done)`
- Auto-detects `ci:local`, else runs typecheck (`tsc -b`, matching CI) + lint + test +
  build. Refuses a green summary on any non-zero exit. On failure, loop back to Phase 4
  (bounded), then re-run done.

### Phase 8 — PR  ->  `Skill(commit-commands:commit-push-pr)`
- `git branch --show-current` first — never commit on the default branch; branch or use
  a worktree.
- Open the PR, then **re-fetch live state**:
  `gh pr view --json reviewDecision,reviews,statusCheckRollup`. Confirm CI is green and
  no review is sitting in CHANGES_REQUESTED before declaring the PR landed-ready.
- `--no-pr` stops here at local-verified. `--deploy` chains `Skill(deploy)` afterward
  (OFF by default — deploy is irreversible and outward-facing).

### Phase 9 — Close out
- **Pre-completion checklist (MUST):** enumerate every item from the original prompt;
  for each, paste the verify command + its exit code; flag anything deferred. No green
  summary without this.
- Stop the run on done and verified, OR if stuck over 15 min, OR at the 4h cap (surface
  that one as a usage leak). Clear the state file when you stop.
- Emit handoff text. If multi-iteration work remains, hand back a ready-to-paste `/loop`
  or `/goal`.

## Hard rules

- **Zero interrupts.** State assumptions and open questions inside the PRD; never pause
  for the user. Sole exception: a protected-path edit -> STOP and request explicit auth.
- **Separate review lane.** Authoring and approval are different passes. The agent that
  built the code must not approve it; route approval to codex / verifier / code-reviewer.
- **Model routing.** haiku = research/search/formatting; sonnet = build and bulk edits;
  opus = architecture, review, hard debugging. Every Agent call passes an explicit
  `model` (a hook enforces this). Cap subagents at 3 concurrent (2 for reviewer/explore).
  Cap subagent output: "verdict + max 5 bullets, no full body".
- **Session hygiene.** Canary at Phase 0; 4h cap; self-cancel rules at Phase 9. No
  full-file dumps into context — extract the ~20 relevant lines.
- **Budget awareness.** This pipeline is expensive — prdforge `deep` alone is ~400k
  tokens and a full unattended run can reach 7-figure tokens. Estimate projected spend at
  Phase 0, honor any explicit "+Nk"/budget directive as a hard ceiling (downgrade
  `--deep`→`--balanced`→`--quick` to stay under it), and surface projected-vs-actual in
  the Phase 9 close-out so a runaway run reads as the usage leak it is.

## Flags

- `--deep` (default): prdforge 6 personas + critic, full consensus pass, ralph-persistence
  build, codex review, multiask escalation on high-stakes.
- `--balanced`: prdforge 4 personas, single ralph pass, codex review.
- `--quick`: prdforge 2 personas, skip the consensus phase, single ralph pass.
- `--no-pr`: stop at local-verified (skip Phase 8 PR).
- `--deploy`: chain `Skill(deploy)` after a green PR (off by default).

## Output / artifacts

- `.omc/research/oneshot-{slug}.md` — research findings
- `.omc/plans/{slug}-prd.html`, `{slug}-prompt.md`, `{slug}-prd.json` — PRD
- `.omc/plans/consensus-{slug}.md` — consensus plan
- `.omc/state/ultrapilot-state.json` — run state (cleaned by cancel)
- An opened PR with green CI (unless `--no-pr`)

## Triggers

`/oneshot`, "oneshot", "one shot one kill", "kitchen sink", "throw everything at it",
"full pipeline", "idea to PR".
