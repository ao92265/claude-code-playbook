---
title: /bad — BMad Autonomous Development
parent: Multi-Model Orchestration
grand_parent: News & Research
nav_order: 3
---
# /bad: BMad Autonomous Development — A Fully Autonomous Sprint Orchestrator

**Source:** r/BMAD_Method, [u/MachineLearner00 — "/bad: BMad Autonomous Development"](https://www.reddit.com/r/BMAD_Method/comments/1scy3jf/bad_bmad_autonomous_development_a_fully/) (2026-04-05). GitHub: [stephenleo/bmad-autonomous-development](https://github.com/stephenleo/bmad-autonomous-development)

## Key takeaways

- **Coordinator-only skill.** `/bad` never writes code — it delegates every unit of work to dedicated subagents with fresh context windows.
- **Git-worktree-per-story isolation** prevents environment pollution and state conflicts.
- **4-step lifecycle:** BMAD Create-Story → Dev-Story → Code-Review → GitHub PR.
- **Self-healing CI loop** auto-fixes implementation bugs until green.
- Rate-limit aware; state-persistent + resumable; automatic conflict resolution.
- Token-hungry — pair with `caveman` and OpenTelemetry monitoring.

## The motivation

> "I've realized that my favorite part of building is the 'discovery' phase: brainstorming, writing PRDs, and designing architecture. But as soon as the planning ends and the 'grunt work' of managing branches, implementation loops, and babysitting CI begins, I lose momentum. So, I built /bad (BMad Autonomous Development): An open-source orchestrator that takes over the second my planning is done, running the entire sprint execution autonomously so I can wake up to a wall of green PRs."

## Architecture

### The autonomous build flow

1. **Dependency mapping** — builds a graph from your `sprint-status.yml` to identify parallelisable stories
2. **Isolated execution** — each story runs in an isolated **git worktree**, preventing environment pollution
3. **The 4-step lifecycle** — every task goes through `BMAD Create-Story → Dev-Story → Code-Review → GitHub PR`
4. **Self-healing CI** — orchestrator monitors CI results and reviewer comments, auto-fixing implementation bugs until status turns green

### Why it works

- **Context isolation:** every step gets a dedicated subagent with a clean slate
- **Rate-limit aware:** proactively checks usage and pauses until resets
- **State persistence + resume:** reads GitHub PR status + local `sprint-status.yml` to know exactly where to pick up
- **Automatic conflict resolution:** optionally auto-merges PRs sequentially, handling merge conflicts as they arise
- **Dependency-aware parallelism:** graph-informed concurrent execution of independent stories

## Install

```bash
npx skills add https://github.com/stephenleo/bmad-autonomous-development
```

**Prerequisite:** BMAD must already be installed. Invoke in Claude Code:

```
/bad
```

First run walks through a setup process.

**Autonomous mode:** Use `auto mode` or `dangerously-skip-permissions`. OP recommends running inside a sandbox to prevent access outside the working directory.

## Community extensions

### TEA test-plan / test-review (Randyslaughterhouse)

Insert BMAD's Test Engineering Architect (TEA) module around dev-story:

```
create-story → test-plan → dev-story → test-review → code-review → PR/merge
```

> "I then have a dedicated E2E testing story per epic that collates all story-level test plans into an epic E2E automated test run and checks for/backfills any coverage gaps. This is used as part of the epic test and close-off process. It's not perfect and the epic-level testing/validation can be a bit time consuming, but it gives me a lot more confidence knowing there's a decent safety net for the automated story build runs, which is where most of the time savings come from."

### Adversarial reviews before dev (RD-Epimetheus)

> "The first step of the 'dev loop' is the creation of a story file. Since I am a glutton for punishment, what I do is I run every story through one party mode review and two adversarial reviews (both are BMAD inbuilt 'functions'). My subjective observation is, that it has made the actual programming phase smoother."

### Model routing by story complexity (Bright_Zebra_8266 + famousmike444)

> "In codex, the sub agents use 5.4 mini at medium thinking. i bet same for copilot (yet to test). now imagine a mini model handling the bmad loop. i read the codex subagent docs and the models can be changed from codex/agents/xx.toml."

**Wish list from famousmike444:**

- Use smaller less expensive models for lower complexity tasks
- Evaluate story complexity prior to dev-story to determine model
- Visual dashboard: status, model used per task, tokens consumed, code-review findings, human-to-do list

OP: *"Great ideas! I know what I'm doing this weekend!"*

### Validate-story loop (Bright_Zebra_8266)

> "create story → validate story → dev → review → PR. No matter how smart the model is, validate story always captures gaps and skipped acceptance criteria."

## Token cost — acknowledged trade-off

Top comment: *"If you have tokens to spare."*

OP response:

> "Yes, BMAD is token hungry. The main reason `/bad` tracking the Claude Code limits and pause until it resets is because I kept hitting into limits regularly. I feel the latest BMAD versions (6.2+) with progressive disclosure is way better in token consumption than prior versions though."

### Pair with

- [caveman plugin]({{ site.baseurl }}/docs/news/caveman-75-percent-tokens/) for output compression
- [Rezvani OpenTelemetry stack]({{ site.baseurl }}/docs/news/claude-code-monitoring/) for visibility into subagent spend
- Loop-breaker heuristic (hand jammed tasks to Codex) — see [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/)

## When to use

- Sprint-level execution where PRDs + stories are already written
- Maintenance backlogs of well-scoped, parallelisable tickets
- Dependency-bumping campaigns across many services
- Generated-code-heavy tasks (migrations, scaffolding)

## When NOT to use

- Exploratory or discovery work (that's the human part)
- Customer-facing changes without human PR review
- Anything touching regulatory/compliance decisions
- Projects without good CI coverage — the self-heal loop relies on signal

## The difference from "just run BMAD until a blocker"

> "I started that way. Then found there were repeated patterns that kept popping up so I wrote this skill to follow through all those as well. For example, the merging of PRs sequentially, fixing merge conflicts as they appear. Or the waiting for CI to complete and fix issues automatically. Or identifying dependencies to pick the next few parallelisable tasks to build concurrently. /bad is ultimately a workflow following best practices I've discovered so far."

## Related Playbook pages

- [BMad Autonomous Development]({{ site.baseurl }}/docs/bmad/) — full reference with architecture diagrams
- [Cost & Observability]({{ site.baseurl }}/docs/cost-and-observability/) — OpenTelemetry pairing
- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — the loop-breaker pattern for stuck subagents
