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
