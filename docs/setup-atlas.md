---
title: Setup Atlas
nav_order: 42
parent: Architecture
---
# The full setup atlas — one diagram of a real stack

Most "here's my CLAUDE.md" posts show the rules file and stop. The rules file is the smallest part of it. The thing that makes a setup productive is everything around it: the hooks that fire on every prompt, the agents work gets routed to, the gates that block a bad commit, and the proxies and control towers that let you run ten terminals at once.

This page is one diagram of a complete working stack. It's the [oh-my-claudecode](https://github.com/) orchestration layer plus custom hooks, skills, and infrastructure, drawn as a single wall-chart so the layers are visible at once.

![Full Claude Code setup atlas — request lifecycle with decision gates, agent and skill catalogs, hooks, MCP servers, scheduled daemons, and the multi-terminal fleet and proxy layer]({{ site.baseurl }}/assets/images/claude-setup-atlas.png)

> Source HTML (editable, self-contained): [`claude-setup-atlas.html`]({{ site.baseurl }}/assets/images/claude-setup-atlas.html). Open it in a browser and re-export.

---

## How to read it

Four zones.

**The request lifecycle (center spine).** Every prompt runs top to bottom through real decision gates, not a straight line.

- Entry gate, then context, then triage. Hooks rewrite and guard the prompt. Context loads (CLAUDE.md ×4, memory, wiki, last handoff). A triage diamond splits trivial / keyword / complex.
- Ambiguity gate. A vague plan loops back through `deep-interview` / `ralplan` consensus until ambiguity drops under threshold. This is the loop that stops the model writing 200 confident, wrong lines.
- Checks-pass gate. After the verify lane (a separate reviewer pass, never self-approve), a failed check routes to Fix & Iterate and loops back to execution. Three strikes triggers a rewind.
- High-stakes gate. Security, prod, or irreversible work forks into a 5-way `multiask` review before commit.

The two loop-backs are the part that matters. The model gets trusted inside a fence that catches its mistakes, not blind.

**The catalogs (left rail and atlas bands).** Operating principles, model routing (haiku / sonnet / opus by task), the agent catalog (~35 named agents across core, specialist, spec-pipeline, and built-in), and the skill registry grouped by job: planning, research, execution loops, quality gates, prose, frontend, memory, ops, meta.

**The gates (right rail).** Execution modes, planning gates, quality gates, research modes, and session controls. Each one lists what it checks and what it blocks.

**Infrastructure and the fleet (bottom bands).** This is the part nobody draws.

- Hooks by event, every script across all eight hook events.
- MCP servers, scheduled launchd daemons, plugins, and the `.omc/` state tree.
- The multi-terminal fleet. 6–10 Claude sessions in parallel, each with its own stop-handoff. `/morning` consolidates them into one briefing. A local triage board (`rohcna`) sorts the parked ones into needs-you / mid-task / resume / stale and jumps you straight to the iTerm pane.
- Proxies in front of the model: a token-killing Bash-rewrite proxy (60–90% off), a context-compression proxy, and a 60-second re-auth daemon.
- Headless and subscription: driving the CLI with `stream-json --resume` to build subscription-funded agents with no API key.

---

## The lesson

A single CLAUDE.md improves one session. The setup above is what lets you run many sessions, in parallel, cheaply, with bad output caught before it ships. The rules file is one box on the chart. The decision gates, the verify lane, and the fleet and proxy layer are the rest of it.

Build the lifecycle fence first. Add the inventory as you grow. Wire up the fleet and proxies last, once you've got more terminals than attention.
