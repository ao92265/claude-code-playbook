---
title: 30-Day Usage Insights
nav_order: 4
parent: "Patterns & Techniques"
permalink: /docs/usage-insights/
---

# 30-Day Usage Insights — What Actually Gets Used

*Snapshot: 2026-03-22 → 2026-04-21, sourced from `~/.claude/projects/` JSONL logs. One author (Alex), 2,228 sessions across 320+ project directories. Methodology below.*

This page is a field report, not advice. It answers: **when a working engineer uses Claude Code across dozens of repos, what actually shows up in the logs?** Cross-check your own usage with the same commands at the end — you will likely find the same two or three skills doing 80% of the work.

## Headline numbers

| Signal | Value |
|---|---|
| Sessions in last 30 days | **2,228** |
| Unique project directories touched | **320+** |
| Dominant repo (share of sessions) | **Top repo — ~47%** |
| Tool calls across the whole corpus | ~50,000 |
| Slash-command invocations (skill-level, excl. `/exit` `/login` `/clear`) | ~70 |

## Tool mix

| Tool | Calls | Read |
|---|---:|---|
| Bash | 24,608 | shell verification, builds, git |
| Read | 11,852 | code exploration |
| Edit | 4,879 | targeted code changes |
| Grep | 3,460 | content search |
| Glob | 1,390 | file discovery |
| Write | 1,294 | new-file authoring |
| Agent | 903 | sub-agent delegation |
| Task\* (Create/Update/List/Output) | 884 | long-running task orchestration |
| ToolSearch | 364 | deferred-tool loading |
| Skill | 161 | skill invocation |
| WebFetch | 157 | docs + article reading |

**Takeaway:** Bash + Read dominate ~73% of all tool calls. The "read a lot, edit narrowly" ratio (Read:Edit ≈ 2.4:1) is a healthy signal — it means exploration precedes change. If your ratio inverts (more Edit than Read), you are probably guessing.

## MCP servers

```
computer-use       ████████████████████  ~427 calls
chrome-devtools    ████████████████░░░░  ~345 calls
oh-my-claudecode   ████████░░░░░░░░░░░░  ~164 calls
historian          █░░░░░░░░░░░░░░░░░░░   ~11 calls
context7           ░░░░░░░░░░░░░░░░░░░░   occasional
```

**Takeaway:** Two MCPs (`computer-use`, `chrome-devtools`) account for ~80% of MCP traffic — both visual/automation. Everything else is sparse. If you have five MCPs configured but only two show up in logs, the other three are context-window tax for no return. Audit and prune.

## Top slash commands (30d)

| Command | Uses/mo | Why |
|---|---:|---|
| `/mcp` | 10 | swap MCPs mid-session without restart |
| `/effort` | 10 | bump reasoning when stuck on hard problems |
| `/bad` | 10 | BMAD autonomous sprint orchestrator (parallel worktree-isolated stories) |
| `/extra-usage` | 9 | quota check before heavy work |
| `/ultraplan` | 4 | Planner / Architect / Critic consensus before execution |
| `/oh-my-claudecode:team` | 3 | N coordinated agents on a shared task list |
| `/oh-my-claudecode:autopilot` | 3 | full idea-to-working-code execution |
| `/loop` | 3 | recurring-interval polling / babysitting |
| `/model` | 3 | model swap mid-session |
| `/compact` | 2 | manual conversation compression |
| `/gravy` | 2 | Teams duck-assistant persona |

**Takeaway:** Three workflow skills (`/bad`, `/ultraplan`, `/oh-my-claudecode:autopilot`+`team`) account for most autonomy usage. Everything else is scaffolding. If your team has 30 skills and only three get used, the other 27 are cognitive debt.

## Repo concentration

| Repo | Sessions | Share |
|---|---:|---:|
| Primary product repo | ~1,045 | 47% |
| Internal orchestration tool | ~70 | 3% |
| This playbook | ~43 | 2% |
| Internal integration repo | ~19 | <1% |
| (long tail: 320+ dirs) | balance | ~47% |

**Takeaway:** One repo eats half the attention. The long tail is real — 320+ distinct project directories in 30 days — but most are one-off sessions. Invest in CLAUDE.md quality for the top 3 repos; don't bother authoring CLAUDE.md for the long tail (Claude reads the code fine).

## What's missing from the logs (and what that means)

- **`/compact` only 2× in 30 days.** Context rot is a known degrader. Under-using `/compact` means sessions that should have been split are being run long. Worth a habit.
- **`context7` ~2 MCP calls.** Docs-lookup MCP is configured but barely used — Claude 4.x is usually right from memory, but when it's wrong on a library API, `context7` is the cheap fix. Under-used.
- **`historian` only 11 calls.** Own-history search is a silver bullet for "did I already solve this?" — deeply under-used.
- **No `/gsd:*` commands in top-30.** Either the GSD flow isn't landing, or it's being invoked through shortcuts that don't surface in command logs.

## How to run the same analysis on your own logs

```bash
cd ~/.claude/projects

# Top tool names, past 30 days
find . -name "*.jsonl" -mtime -30 -print0 \
  | xargs -0 -P 8 -I{} sh -c 'grep -oE "\"name\":\"[A-Za-z_]+\"" "{}" 2>/dev/null' \
  | sort | uniq -c | sort -rn | head -25

# Top MCP servers
find . -name "*.jsonl" -mtime -30 -print0 \
  | xargs -0 -P 8 -I{} sh -c 'grep -oE "\"name\":\"mcp__[A-Za-z0-9_-]+" "{}" 2>/dev/null' \
  | sed -E 's/.*mcp__([^_]+(_[A-Za-z0-9-]+)?).*/\1/' \
  | sort | uniq -c | sort -rn

# Top slash commands
find . -name "*.jsonl" -mtime -30 -print0 \
  | xargs -0 -P 8 -I{} sh -c 'grep -hoE "<command-name>[^<]+" "{}" 2>/dev/null' \
  | sed -E 's|<command-name>||' \
  | sort | uniq -c | sort -rn | head -30

# Top repos by session count
ls -d -- ~/.claude/projects/-Users-*-Repos-* \
  | xargs -I{} sh -c 'printf "%6d %s\n" "$(find {} -name "*.jsonl" -mtime -30 | wc -l)" "$(basename {})"' \
  | sort -rn | head -15
```

Every command above runs read-only against JSONL session logs Claude Code already writes. No extra tooling required.

## May 2026 follow-up — friction-driven skill additions

*Snapshot: 2026-04-15 → 2026-05-11, 116 sessions analyzed, 296 commits.*

Second `/insights` run surfaced a different shape of friction than the March snapshot. Top categories:

- **Wrong initial approach (47)** + **buggy first code (40)** — Claude takes a wrong-headed first pass and needs redirection. Tradeoff: faster than writing detailed specs upfront, but loses an iteration per task.
- **Hook & permission blocks (~15)** — `prisma/schema.prisma` and protect-paths repeatedly halted long autonomous runs. One borderline incident: Claude tried to bypass the hook via Bash before backing off.
- **CI/local typecheck mismatch** — local `tsc --noEmit` passed while CI `tsc -b` (project build mode) failed. Forced post-merge re-runs.
- **Wrong-branch commits** — fixup commits landed on feature PR branches multiple times, requiring cherry-pick recovery.
- **Tone rework on non-technical drafts** — first-pass Slack/email drafts to non-technical recipients consistently bulleted + too technical, requiring a second pass.

### Concrete fixes shipped

Four user-level skills + one hook upgrade addressing each friction category:

| Skill / Hook | What it does | Friction it kills |
|---|---|---|
| `~/.claude/hooks/pre-commit-verify.sh` | Echoes current branch + runs `tsc -b` (CI parity) before any commit; blocks on type error unless `[wip]`/`[skip-verify]` | Wrong-branch commits + tsc mismatch |
| `/pr-merge-queue` skill | Batched merge loop (5 PRs/batch), checkpoint summaries, branch verify, protected-path skip | Ralph-loop overruns + usage-limit mid-merge |
| `/pr-fleet` skill + headless `pr-fleet.sh` cron wrapper | Coordinator + 3-concurrent worker subagents, one worktree per PR, escalation list for schema/migrations | Sequential merge marathons (35+ PRs/session) |
| `/tdd-fix` skill | RED→GREEN→SHIP loop, full CI parity (`tsc -b && npm test && npm run lint`) before PR | Wrong-approach + buggy-first-pass on bug fixes |
| `/draft-reply` skill | Audience-first checklist (recipient/level/tone/action) before drafting | Tone rework on non-technical replies |
| CLAUDE.md "Insights-Learned Rules" section | Branch discipline, typecheck parity, protected paths, attribution verification | Codifies the above so it survives a fresh session |

### Lessons that generalize

1. **Friction analytics beat introspection.** A second monthly `/insights` run surfaced patterns I had not noticed manually — particularly the typecheck-mismatch and tone-rework loops. The numbers (47 + 40 + 15) are the prioritization signal.
2. **Convert recurring corrections into hooks, recurring workflows into skills.** Hooks are deterministic gates; skills are probabilistic playbooks. Branch verification belongs in a hook because forgetting it is silent. Audience framing belongs in a skill because it is judgment-driven.
3. **Parallelism is a friction fix, not just a speedup.** The sequential ralph-loop pattern was hitting usage limits mid-batch, which forced restart with stale context. `/pr-fleet` with 3 concurrent worker subagents per worktree finishes inside a single context window and only escalates protected-path PRs to the operator.
4. **Pre-authorize protected paths at planning time, not edit time.** The schema-protect hook is correct; the workflow around it was wrong. New rule: Claude must surface "this requires schema changes" during the plan, not after attempting an edit and getting blocked.

## May 2026 follow-up #2 — third `/insights` run, horizon items shipped

*Snapshot: 2026-04-22 → 2026-05-27, 62 sessions analyzed, 148 commits.*

Third pass surfaced two new friction shapes plus three "on the horizon" workflows the report nominated. Six concrete additions shipped same-day:

| Change | Type | Friction it kills |
|---|---|---|
| `~/.claude/read-once/hook.sh` — Read-before-Edit guard | PreToolUse hook | The "File must be read first" error class that interrupted batch PR sweeps. Records every Read into a per-session list; blocks Edit/Write/MultiEdit on un-Read existing files. Bypass: `OMC_SKIP_HOOKS=read-once` |
| CLAUDE.md "Pre-completion checklist" rule | Prompt-level directive | "Why stop, keep going" stalls. Before declaring multi-task work done, MUST enumerate every original ask + paste verify command + exit code + flag deferred items |
| `/pr-fleet` extension — shared state + pre-flight | Skill upgrade | Workers stalling silently when one hits a firewall/hook block. Adds `.omc/state/pr-swarm.json` with atomic mkdir-mutex claim/release, plus a `preflight` step that hard-fails on missing `gh`/`jq`/auth/fetch before any worker spawns |
| `/refactor-loop` skill | New skill | Half-baked refactors shipping regressions. Generates Playwright/Vitest characterization tests pinning current behavior, commits them on a baseline branch, then iterates the refactor until tests stay green (max 20 iterations) |
| `/critic` skill | New skill | Plans approved without adversarial second-opinion. Wraps the OMC critic agent for a one-shot review covering scope creep, symptom-vs-root-cause, missing tests, fabricated facts, unverified assumptions |
| pr-fleet state-helpers CLI | New script | `state-helpers.sh init|claim|done|block|report|preflight` for worker subagents to read/write shared state without race conditions |

### What the report got wrong

The `/insights` recommendation list assumed several gaps that turned out to already be filled:

- "Firewall blocks `--force-with-lease`" — `firewall.sh:33` already allows the safe variant; the friction was a stale workflow assumption, not a hook bug.
- "Add anti-sycophancy rule" / "plain-English rule" — both already in CLAUDE.md ("Epistemic + Candor" and "Communication Register" sections).
- "Build a /pr-fix skill" — covered by existing `pr-fleet` / `pr-merge-queue` / `wraith-pr-review`.

Gap analysis BEFORE building saved roughly 4 hours of duplicate-work effort. The pattern: every `/insights` recommendation needs a "does this already exist?" pass before it goes on the build list.

### Lessons that generalize

1. **A no-op stub hook is worse than no hook.** `~/.claude/read-once/hook.sh` had been a `exit 0` placeholder for months. The slot was reserved but the enforcement was zero, so the friction the hook was supposed to kill kept appearing. Audit your `settings.json` for hooks whose script body is a stub.
2. **Worker swarms need shared state OR they're sequential cosplay.** Pre-state-file, three `pr-fleet` workers running in parallel could each claim the same PR; in practice they didn't, but only because triage filtered to disjoint queues. With explicit `claim`/`done`/`block` semantics the swarm survives partial failures and overlapping triage, which is the whole point.
3. **Refactor-first ≠ TDD.** Existing `tdd-fix` is bug-fix-first: write the failing test, then fix. `refactor-loop` is the inverse: pin behavior FIRST with characterization tests, then refactor without changing behavior. Conflating them led to the Centurion redesign shipping regressions.
4. **Horizon items are usually one-day builds.** The report framed self-healing swarms and TDD refactor loops as "as models get stronger." Both shipped same-day as small extensions to existing skills. Don't defer ambitious-sounding workflows until you've checked whether they're actually 200 lines on top of what already exists.

## Methodology notes

- Counts are aggregated from `~/.claude/projects/*/*.jsonl` files with `mtime` ≤ 30 days.
- **Work-type breakdown** is a *tool-mix proxy*, not semantic classification of user intent — it groups tools into Build / Analyze / Plan / Debug / Quality by function and reports relative shares. Honest approximation, not ground truth.
- Sub-agent sessions are counted separately in the session totals (they live in `subagents/` subdirs). The ~2,228 figure includes them.
- Slash-command counts exclude system commands (`/exit`, `/login`, `/clear`, `/resume`, `/status`) to focus on skill-level use.

## Related pages

- [Anti-Patterns]({{ site.baseurl }}/docs/anti-patterns/) — the "don't do this" guide
- [Skills Ecosystem]({{ site.baseurl }}/docs/skills-ecosystem/) — how to curate the few skills that earn their place
- [Team Onboarding template]({{ site.baseurl }}/templates/ONBOARDING-TEAM/) — the filled-in version of this data as a shareable new-starter guide
- [Cost & Observability]({{ site.baseurl }}/docs/cost-and-observability/) — instrumenting the logs this page reads from
