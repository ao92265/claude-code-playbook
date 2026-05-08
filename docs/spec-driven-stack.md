---
title: Spec-Driven Stack 2026
nav_order: 14
parent: Patterns
---
# Spec-Driven Stack 2026: Big 5 + GS

Map of the spec-driven dev methodology crystallizing across the OSS community in 2026. Six tools, one operating model: replace ad-hoc "vibe coding" with a verifiable pipeline from spec to production.

> Why it matters: vibe coding fails at ~80% complete because context overflows, the model contradicts earlier decisions, and there is no audit trail. Spec-driven dev fixes the root cause — every change traces back to a human-readable spec.

---

## The Stack

| # | Tool | Role | Stars |
|:--|:-----|:-----|:------|
| 1 | **BMAD** | Agent team + 7 human gates (G0–G6) | 46k |
| 2 | **GSD** (Get Shit Done) | Wave execution, fresh 200K context per wave | 58k |
| 3 | **Tracer BART mode** | Parallel ticket orchestrator with closed-loop verify | — |
| 4 | **GitHub Spec Kit** | Vendor-agnostic spec layer (`spec.md → plan.md → tasks.md`) | 91k |
| 5 | **Claude Code** | Execution engine: plan mode, auto mode, OTel, MCP | — |
| 6 | **GStack** (Gary Tan) | 9-role virtual dev team incl. security officer + QA | — |

---

## How They Compose

```
SpecKit  ──►  spec.md / plan.md / tasks.md  (the source of truth)
   │
   ├── BMAD agents (Mary, John, Winston) refine spec, gate G0–G2
   │
   ├── GSD waves: Discuss → Plan → Execute → Verify (fresh window each)
   │
   ├── BART mode: parallelise independent tickets, dependency-aware
   │
   ├── Claude Code: plan mode for first run, auto mode for iterations
   │       ├── MCP: DB / repo / API as native tools
   │       └── OpenTelemetry: every decision becomes a trace span
   │
   └── GStack: security officer reviews every PR, QA runs every suite
```

Each layer adds a different kind of verification. BMAD = human gates. GSD = context discipline. BART = closed-loop self-check. SpecKit = artifact chain. Claude Code = audit trail. GStack = role-separated review.

---

## Tool-by-Tool

### 1. BMAD — Blueprint Method for Agentic Development
- **Insight:** vibe coding has no pre-work. BMAD forces planning before code.
- **Roles:** Mary (analyst → PRD), John (PM → stories), Winston (architect → system design).
- **Governance:** seven HITL gates G0–G6. G0 problem framing → G6 production deploy. No skipping.
- **Result:** 50–70% reduction in major refactors vs. vibe-coded baselines.
- See [BMad Autonomous Development](bmad.md) for the `/bad` orchestrator we already use.

### 2. GSD — Get Shit Done
- **Problem solved:** context rot. Long sessions degrade output quality.
- **Fix:** never let context get long. Fresh 200K window per wave. Output of one wave seeds the next.
- **Loop:** Discuss → Plan → Execute → Verify, then commit and start a new window.
- **Aligns with our existing rule:** `/compact at 50%, /clear at 80%` (see global `CLAUDE.md`).

### 3. Tracer BART mode — Smart YOLO
- **Scope:** runs an entire epic, not a single task.
- **Mechanic:** breaks the spec into parallel tickets, dispatches agents, manages dependencies.
- **Closed-loop verify:** failed verification triggers a re-plan, not a retry of the same prompt.
- **Case study:** analytics dashboard spec → working product in **93 minutes**.

### 4. GitHub Spec Kit — `specify`
- **Why it leads in stars (91k):** vendor-agnostic. Works with Claude, GPT, Gemini, any agent.
- **Install:** `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git`
- **Six commands:** `specify`, `plan`, `tasks`, `implement`, `constitution`, `tasks-to-issues` (MCP → GitHub).
- **Artifact chain:** `spec.md → plan.md → tasks.md`. Every file is plain markdown — any agent can pick it up cold.

### 5. Claude Code — execution engine
- **Plan mode:** writes the full plan, you review, then executes. Equivalent to BMAD G-gates at the per-task level.
- **Auto mode:** autonomous within permission boundaries.
- **OpenTelemetry tracing:** every prompt → code-change link visible in Langfuse / any OTel backend.
- **MCP:** DB, repos, internal APIs as native tools. Agent operates on the real system, not in isolation.
- See [Cost & Observability](cost-and-observability.md) for our OTel Docker stack.

### 6. GStack — Gary Tan's 9 roles
- **Premise:** stop thinking single assistant. Think virtual dev team with org structure.
- **Roles by default:** CEO, Engineering Manager, QA, Security Officer, Docs Engineer, Frontend, Backend, DevOps, Data.
- **Security Officer alone is worth the setup cost** — every PR gets a security review for free.
- **`/browse`:** agents open Chrome DevTools Protocol, visually inspect the UI, detect layout breaks. Visual QA at agent speed.
- **Headline claim:** 10k LOC / 100 PRs per week. **Disputed** — community has not independently replicated. Treat as ceiling, not baseline.

---

## What to Adopt at Harris (priority order)

1. **Spec Kit** — install globally (`specify` CLI is now on this machine). Highest ROI, lowest friction. Try on one Wraith ticket.
2. **GSD discipline** — already partially in place via `/compact` and `/clear` rules. Formalise the wave loop: `Discuss → Plan → Execute → Verify`.
3. **GStack security-officer pattern** — adapt for Wraith / Centurion. Run a `security-reviewer` subagent on every PR before merge.
4. **OTel traces on Claude Code** — gives auditable production trail. Useful for regulated workloads.
5. **BMAD G-gates** — only on net-new builds, not bugfixes. Gate overhead is real on small work.

---

## What to Skip / Be Skeptical Of

- **GStack 10k-LOC/wk number** — unreplicated. Don't quote it externally.
- **BMAD G0–G6 on small fixes** — gate overhead exceeds bug-fix budget. Reserve for new builds.
- **BART mode unattended overnight** — closed-loop verify is good, but our `Marathon guard` rule still applies (no 60+ min unattended runs).

---

## Resources

- Spec Kit: <https://github.com/github/spec-kit>
- BMAD: see existing [BMad guide](bmad.md)
- GStack: Gary Tan's repos (multi-role agent harness)
- Adoption rollout: see [Adoption Playbook](adoption-playbook.md)
