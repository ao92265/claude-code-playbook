---
title: RPI Workflow
parent: Resources
nav_order: 38
---
# RPI Workflow — Research → Plan → Implement

A structured alternative to BMAD. Three explicit phases with a GO/NO-GO gate between them. Each phase has its own subagents and produces a named artefact. Most useful for medium-to-large changes (≥1 day of work, ≥10 files) where ad-hoc planning loses the thread.

## When to Use

| Change size | Use |
|------------|-----|
| < 1 hour, < 5 files | Direct edit. Skip RPI. |
| 1 hour – 1 day, single concern | Lightweight: plan in chat, execute. |
| ≥ 1 day, multi-file, multi-concern | **RPI** |
| ≥ 1 sprint, cross-team, regulatory | RPI + BMAD personas |

## The Three Phases

### Phase 1 — Research (read-only)

Goal: understand the problem space and produce a GO/NO-GO recommendation. **No code changes.**

Subagents:
- `research-explorer` — codebase reconnaissance (greps, file maps)
- `research-domain` — pulls external docs / RFCs / vendor SDKs (Context7, web)
- `research-risk` — identifies blockers, hidden coupling, regression vectors

Output: `tasks/<slug>/research.md` with sections **Findings**, **Unknowns**, **Risks**, **GO/NO-GO**.

Slash command: `/rpi:research <slug>`. Stop here if NO-GO. Do not let momentum carry you into a phase you should not be in.

### Phase 2 — Plan (read-only)

Trigger: research returns GO. Three planning subagents run in parallel:

- `plan-pm` → `tasks/<slug>/pm.md` — user-facing scope, success criteria, rollback story
- `plan-ux` → `tasks/<slug>/ux.md` — interaction surfaces, copy, error states
- `plan-eng` → `tasks/<slug>/eng.md` — module touch list, migration order, test strategy

Then `plan-synth` merges them into `tasks/<slug>/PLAN.md` and lists open questions. Loop back to PM/UX/eng if the synthesis surfaces a contradiction.

Slash command: `/rpi:plan <slug>`. The merged PLAN.md is the contract for phase 3.

### Phase 3 — Implement

Trigger: PLAN.md approved. One executor agent at a time, code-reviewer agent runs after each chunk.

- `executor` (sonnet) — works through the eng.md module list in order
- `code-reviewer` — independent pass after each chunk, blocks merge on rated issues
- `verifier` — runs the test plan from eng.md and posts pass/fail evidence

Slash command: `/rpi:implement <slug>`. Stop and re-plan if the executor hits a blocker not in research/plan — do not improvise.

## Artefact Layout

```
tasks/
  <slug>/
    research.md      # phase 1
    pm.md ux.md eng.md   # phase 2 inputs
    PLAN.md          # phase 2 output (the contract)
    review-<chunk>.md  # phase 3, per chunk
    verify.md        # phase 3 final evidence
```

Commit each phase artefact before starting the next. Future sessions can pick up mid-flow because the contract is on disk.

## RPI vs BMAD

| | RPI | BMAD |
|---|-----|------|
| Shape | Linear, gated | Persona-based, parallel |
| Best for | Medium changes with clear scope | Large changes needing role separation |
| Output | Single PLAN.md contract | Multiple persona artefacts |
| Stop conditions | NO-GO at gate | Persona consensus |

They compose: RPI for the structure, BMAD personas as the agent identities inside each RPI subagent.

## Pitfalls

- **Skipping the gate.** If research returns NO-GO, do not start planning anyway because "we already paid the research cost". Sunk-cost trap.
- **One mega-plan.** If PLAN.md is more than ~200 lines, split the work — that's a sign the change should be two RPI runs.
- **Executor without reviewer.** Code-reviewer is not optional. Self-review in the same context is invalid.
- **Memory leak between phases.** Phase 3 must not load research.md beyond what eng.md cites — context bloat kills implementation accuracy.

## See Also

- [BMAD](bmad.md) — persona-based alternative
- [Workflows](workflows.md) — decision tree
- [Steering Files](steering-files.md) — keeping multi-session work coherent
