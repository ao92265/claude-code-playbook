---
title: Codex Parity
parent: Help
nav_order: 4
---
# Matching Codex's Workflow Stack in Claude Code

OpenAI Codex markets four workflow features: **Agents.md**, **custom Skills**, **Record & Replay**, and **Automations**. Claude Code already covers most of them. This page maps them one-to-one, then shows how to build the two pieces Claude doesn't ship out of the box.

## The map

| Codex feature | Claude Code equivalent | Ships by default? |
|:--|:--|:--|
| Agents.md (project profile, workflow rules) | `CLAUDE.md` (global + project) + `AGENTS.md` (also read) + memory files | Yes |
| Custom Skills (`@`-invoke) | Skills (`/name`), authored via `/skillify`, `/autoskill`, skill manager | Yes |
| Plan Mode | Native plan mode | Yes |
| Fan-out subagents | Subagents + git worktrees | Yes |
| Automations (scheduled runs) | `/loop`, `/goal`, plus OS scheduler (launchd/cron) | Partly — no registry view |
| Record & Replay (demo → skill) | `/skillify` reads the *conversation*, not your *actions* | No — build it |

The two rows that aren't a clean match are the build targets below.

## Gap 1: Record & Replay (demo → skill)

Codex watches you perform a task and synthesizes a skill. Claude's `/skillify` extracts a skill from the **conversation transcript** — useful, but it never saw the commands you ran in your own terminal or the clicks you made in a browser. Close that with two capture layers feeding one synthesizer skill.

### CLI layer — record a terminal session

`script` (present on macOS/Linux) records a session to a transcript. Drop this in `~/.claude/scripts/demo-record.sh`:

```bash
#!/usr/bin/env bash
# demo-record.sh — record a terminal session for later skill synthesis.
set -euo pipefail
slug="$(printf '%s' "${1:-demo}" | tr -cs 'A-Za-z0-9_-' '-' | sed 's/^-*//; s/-*$//')"
out="$HOME/.claude/demos/${slug:-demo}-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$out")"
echo "🎬 Recording → $out   (run your task, then type 'exit')"
script -q "$out" "${SHELL:-/bin/bash}" -l || true   # BSD: script -q FILE CMD; GNU: script -q -c CMD FILE
echo "✅ Saved: $out"
```

Then a **synthesizer skill** (`~/.claude/skills/demo2skill/SKILL.md`) reads the newest transcript, strips ANSI/control noise, extracts the command sequence, asks one or two questions (what varies between runs? what counts as success?), and writes a new `SKILL.md`. Reuse the conventions in [Skills Ecosystem](skills-ecosystem.md) and your skill-authoring checklist rather than inventing a format.

Cleaning the transcript before synthesis (handles both BSD and GNU `script` noise):

```bash
LC_ALL=C sed -E \
  -e 's/\x1b\][0-9];[^\x07]*\x07//g' \
  -e 's/\x1b\[[0-9;?]*[ -/]*[@-~]//g' \
  -e 's/\x1b[@-_]//g' -e 's/\r//g' "$transcript" \
| tr -d '\000-\010\013\014\016-\037' \
| grep -vE '^Script (started|done)'
```

### Browser layer — Chrome DevTools Recorder

> **Honest constraint.** A browser-automation MCP (e.g. chrome-devtools) *drives* the browser — it cannot passively log a human's clicks. The clean capture bridge is Chrome's built-in **Recorder** panel: DevTools → **Recorder** → record your flow → **Export** as JSON.

Feed that JSON to the same synthesizer skill. Each step has a `type` (`navigate` / `click` / `change` / `waitForElement`) plus selectors; translate the steps into a readable procedure, and optionally emit a Playwright or MCP playback block so the skill can re-run the flow later.

### Why this beats `/skillify` alone

`/skillify` is great when the work happened *in the Claude session*. Record & Replay captures work you did *outside* it — a manual deploy in your shell, a multi-step web console task — and turns the demonstration itself into the skill.

## Gap 2: Automations registry

`/loop` and `/goal` handle in-session recurring work; the OS scheduler (launchd on macOS, cron on Linux) handles background jobs like a morning digest or a weekly cost audit. What's missing is a single answer to *"what's scheduled, how often, and when did it last run?"* — that state is scattered across plist/cron files and logs.

A small lister gives you the registry view. For launchd:

```bash
#!/usr/bin/env bash
# automations-list.sh — one-screen view of scheduled Claude jobs.
set -euo pipefail
la="$HOME/Library/LaunchAgents"; logs="$HOME/.claude/logs"
printf '%-24s %-20s %-18s %s\n' LABEL CADENCE "LAST RUN" STATUS
shopt -s nullglob
for p in "$la"/com.*.claude-*.plist; do
  label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$p" 2>/dev/null || basename "$p" .plist)"
  if iv="$(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$p" 2>/dev/null)"; then
    cad="every ${iv}s"
  else cad="calendar"; fi
  log="$logs/${label}.log"
  last="never"; st="-"
  [ -f "$log" ] && { last="$(date -r "$log" '+%Y-%m-%d %H:%M')"; [ -s "$log" ] && st=ok || st=empty; }
  printf '%-24s %-20s %-18s %s\n' "${label#com.}" "$cad" "$last" "$st"
done
```

Wrap it in an `/automations` skill with `list` / `inspect <label>` (tail the log) / `add` (scaffold a new plist from a template, then `launchctl load` **after confirming with you** — never auto-load a recurring autonomous run). On Linux, swap the launchd scan for `crontab -l` parsing.

## Honest limits

- **No live capture of GUI clicks.** Browser flows go through Chrome's Recorder export, not passive logging.
- **Recording needs a real terminal.** The `record` step runs in your shell, not inside an agent tool call — the agent hands you the command to run.
- **Scheduling is OS-level.** There's no hosted "Automations tab"; you own the launchd/cron entries (which also means full shell power and no vendor lock-in).

## See also

- [Skills Ecosystem](skills-ecosystem.md) — discovering and authoring skills
- [Workflows](workflows.md) — which skill to reach for when
- [Comparison](comparison.md) — Claude Code vs Codex and others
