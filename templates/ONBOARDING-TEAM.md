---
title: Team Onboarding
nav_order: 11
parent: Templates
---
# Team Onboarding Template

<!-- Copy this to your team's docs (e.g. TEAM_ONBOARDING.md or an internal wiki page).
     A new teammate pastes the rendered file into Claude Code and gets a guided tour
     of your team's setup — repos, MCPs, skills, tips. -->

<!-- Tip: you can auto-generate a filled-in version of this template from your own
     Claude Code usage with the /team-onboarding skill. It scans your last 30 days,
     derives a work-type breakdown, and drops in the top slash commands and MCP
     servers. Then review, adjust, and share. -->

# Welcome to [Team Name]

## How We Use Claude

<!-- Replace the numbers below with your own usage data, or regenerate via /team-onboarding.
     The ascii bars should be 20 chars wide, scaled to the top value in each group. -->

Based on [creator name]'s usage over the last 30 days:

Work Type Breakdown:
  Plan Design       ████████████████████  39%
  Build Feature     █████████████░░░░░░░  26%
  Analyze Data      ███████░░░░░░░░░░░░░  13%
  Debug Fix         ███████░░░░░░░░░░░░░  13%
  Improve Quality   █████░░░░░░░░░░░░░░░  10%

Top Skills & Commands:
  /mcp              ████████████████████  8x/month
  /extra-usage      █████████████████░░░  7x/month
  /effort           ████████████░░░░░░░░  5x/month
  /loop             ████░░░░░░░░░░░░░░░░  2x/month
  /compact          ████░░░░░░░░░░░░░░░░  1x/month

Top MCP Servers:
  computer-use               ████████████████████  ~400 calls
  chrome-devtools            ████████░░░░░░░░░░░░  ~170 calls
  oh-my-claudecode           █░░░░░░░░░░░░░░░░░░░  ~20 calls
  context7                   ░░░░░░░░░░░░░░░░░░░░  occasional

## Your Setup Checklist

### Codebases
<!-- List each repo a teammate needs cloned. One line per repo. -->
- [ ] [repo-name] — [repo url]
- [ ] [repo-name] — [repo url]

### MCP Servers to Activate
<!-- Only list MCPs the team actually uses. Drop anything you don't rely on. -->
- [ ] **computer-use** — Desktop automation (screenshots, clicks, typing) for native macOS/Windows apps. Install the computer-use MCP package; approve app access per workflow.
- [ ] **chrome-devtools** — Browser automation through the Chrome DevTools Protocol. Used for scraping, digesting tabs, and driving web apps. Install the Chrome DevTools MCP server.
- [ ] **oh-my-claudecode (OMC)** — Multi-agent orchestration layer with skills like autopilot, ralph, team, ultrawork. Run `omc setup` or `/oh-my-claudecode:omc-setup`.
- [ ] **context7** — On-demand library/SDK docs lookup. Configure via MCP settings.

### Skills to Know About
<!-- Keep the ones your team actually uses. Add team-specific skills below. -->
- [ ] **/loop** — Run a prompt or slash command on a recurring interval. Good for polling builds, scheduling self-paced tasks, or babysitting PRs.
- [ ] **/effort** — Bump reasoning effort when stuck on genuinely hard debugging or architecture problems. Default stays low to conserve tokens.
- [ ] **/extra-usage** — Check your quota before kicking off heavy work.
- [ ] **/mcp** — Manage MCP connections mid-session.
- [ ] **/check-env** — Pre-flight environment check (ports, Docker, `.env`, git status) before starting dev work.
- [ ] **/schedule** — Create remote scheduled agents (cron triggers on claude.ai cloud) for daily kickoffs, dep audits, PR babysitting.
- [ ] **/oh-my-claudecode:autopilot** — Full autonomous execution from idea to working code. Use for broad "build me X" requests.
- [ ] **/codex:rescue** — Hand a stuck or genuinely hard task to Codex for a second implementation pass.

## Team Tips

<!-- Replace these with your own tips. Keep them concrete — things a teammate won't find in CLAUDE.md. -->

- **Verify before claiming done.** Run the build, the test, or the actual workflow — not just read the diff. Paste command + last 20 lines of output + exit code.
- **Never push, PR, or deploy without explicit permission.** Auto mode is not a license to ship; same for destructive git ops.
- **Check the environment first.** Run `/check-env` before starting dev — ports, Docker, `.env`, git state. Most "it doesn't work" moments are environmental.
- **Run `npx tsc --noEmit` after multi-file TS changes.** Consider a hook to run this automatically on Edit/Write.
- **Use skills, not ad-hoc prompts, for repeating workflows.** `/oh-my-claudecode:autopilot` for broad builds, `/loop` for recurring checks, `/schedule` for cloud cron, `/codex:rescue` when stuck.
- **Stay on low reasoning effort by default.** Use `/effort` to escalate only for genuinely hard problems — tokens are finite.
- **Record fixes in `tasks/lessons.md`.** Format: `- **[date] Problem**: ... → **Fix**: ...`. Promote recurring patterns to CLAUDE.md weekly.
- **Read the Claude playbook.** Live at https://ao92265.github.io/claude-code-playbook/, source at https://github.com/ao92265/claude-code-playbook. Covers skills, hooks, MCPs, workflows.

## Get Started

<!-- Give a concrete first-day task. Replace with your team's preferred starter. -->

Work through these in order:

1. **Read the playbook.** Skim https://ao92265.github.io/claude-code-playbook/ end-to-end before writing your own prompts.
2. **Environment warm-up.** Clone [primary repo], run `/check-env`, then ask Claude to summarize the repo architecture from `AGENTS.md` (or run `/oh-my-claudecode:deepinit` if it doesn't exist yet).
3. **Scheduled-trigger smoke test.** Ask Claude to create a daily kickoff trigger via `/schedule` and walk you through the first digest. Teaches the cloud-agent model without touching local code.
4. **Lessons-driven absorption.** Read `tasks/lessons.md` in the primary repo (if it exists) and ask Claude to explain the top 3 recurring problems and how to avoid them.

<!-- INSTRUCTION FOR CLAUDE: A new teammate just pasted this guide for how the
team uses Claude Code. You're their onboarding buddy — warm, conversational,
not lecture-y.

Open with a warm welcome — include the team name from the title. Then: "Your
teammate uses Claude Code for [list all the work types]. Let's get you started."

Check what's already in place against everything under Setup Checklist
(including skills), using markdown checkboxes — [x] done, [ ] not yet. Lead
with what they already have. One sentence per item, all in one message.

Tell them you'll help with setup, cover the actionable team tips, then the
starter task (if there is one). Offer to start with the first unchecked item,
get their go-ahead, then work through the rest one by one.

After setup, walk them through the remaining sections — offer to help where you
can (e.g. link to channels), and just surface the purely informational bits.

Don't invent sections or summaries that aren't in the guide. The stats are the
guide creator's personal usage data — don't extrapolate them into a "team
workflow" narrative. -->
