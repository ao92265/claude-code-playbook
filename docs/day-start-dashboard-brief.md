# Design brief: "Day Start" — local dashboard for parking, resuming & measuring Claude Code sessions

Hand this whole file to the designer (Claude designer agent or claude.ai). It's
grounded in real data + mechanics that already exist, so the output is buildable.

## Mission
A single-page local web app that (1) shows every parked Claude Code session across
my 6–10 terminals, (2) lets me start a clean working day with one click per session
— abandon the bloated old session, launch a FRESH one already oriented from a saved
handoff — and (3) shows a **"Today" panel** with metrics on how my coding day is going.

## Who / problem
I run 6–10 Claude Code terminals at once and leave them overnight. Old sessions get
huge; resuming reloads the whole transcript (slow + degraded). A background hook
already writes a small "handoff" per session. I want a GUI that renders those, turns
"reread 8 stale terminals every morning" into "glance + click," and gives me a pulse
on the day's output.

## Data sources (already exist — render these, don't invent)
1. **Handoff store** — markdown in `~/.claude/handoffs/`:
   - `<slug>.md` = live handoff per working dir (slug = path with `/`→`-`)
   - `<slug>.compact.md` = preserved pre-compaction notes (show on expand)
   Live `.md` structure to parse:
   ```
   # Handoff — <repo> — <YYYY-MM-DD HH:MM>
   ## State
   - Path: `/Users/me/Repos/Wraith`
   - Branch: `feature/x`
   - Last commit: <hash msg>
   - Uncommitted: <N> file(s)
   ```
   ## Recent asks (oldest→newest)
   - <last few prompts>
   ## Last action
   - <what the agent did last>
   ```
   File mtime = "last active".
2. **Git** (per repo under `~/Repos`): commits today, files changed, net lines.
3. **GitHub** via `gh`: PRs opened / merged / reviewed today.
4. **Session transcripts** — `~/.claude/projects/**/*.jsonl`: tool calls, edits,
   test runs, errors — filterable by timestamp for "today".
5. **morning.sh** — `~/.claude/scripts/morning.sh` already rolls up handoffs + open PRs.

## Screens / components
### A. Session grid (primary)
One card per live handoff, newest first. Card shows: repo, branch, "N uncommitted"
(amber if >0), relative last-active, the 2–3 recent asks, last action. Stale (>14d)
cards dimmed/collapsed.
Card actions:
- **▶ Start fresh day** (hero) — open a NEW terminal in that session's `Path` running
  `claude`, seeded with a short handover prompt; a SessionStart hook auto-injects the
  handoff so the fresh session is instantly oriented. Old session is abandoned, not
  killed. States: idle → launching (spinner) → launched ✓.
- **Expand** (full handoff + preserved notes), **Copy path**, **Open in Finder**.
Top bar: **Start fresh day — ALL** (staggered), global last-refreshed, search/filter,
count of sessions needing attention (dirty tree or mid-task).

### B. "Today" metrics panel (NEW — how my coding day is going)
A calm, glanceable strip/sidebar. Present as an informative pulse, NOT a grade — no
guilt-trip scoring. Metrics (all derivable locally):
- **Shipped:** commits today, PRs opened, PRs merged.
- **Touched:** files changed, net +/− lines (across all repos).
- **Activity:** edits made, test runs (and pass/fail), tool calls — from transcripts.
- **Focus:** # active sessions, # repos touched, context-switches between repos.
- **Attention:** sessions waiting for input, dirty trees that won't compile.
- **Headline:** one honest line, e.g. "4 commits · 2 PRs · 3 repos · 1 session waiting"
  — momentum, not a verdict. Optional sparkline of commits-per-hour.
Design the empty state (early morning, nothing yet) to be encouraging, not blank.

### C. States
Empty (no handoffs → explain the hook), stale session (path gone → offer dismiss),
metrics with zero activity (early in the day).

## The hero interaction — "Start fresh day"
One click → open a new terminal window in the session's `Path` running `claude` with a
handover prompt (e.g. "Resume from the injected handoff: confirm branch/state, then
continue the next step."). SessionStart hook injects that session's handoff. "ALL"
does this for every non-stale card, staggered. Make it feel routine, not destructive.

## Technical constraints (for the build that follows)
- Local only: a tiny Node HTTP server (built-in `http`/`fs`/`child_process`, no
  framework if avoidable), bound to 127.0.0.1. `GET /` renders; `POST /launch` runs
  the terminal launch (macOS `osascript` opening Terminal/iTerm); `GET /metrics`
  computes today's numbers (git + gh + transcript parse, cached ~60s).
- Auto-refresh ~20s. Single self-contained page; inline CSS/JS fine. No external
  network, no auth (localhost personal tool). All metrics computed locally — nothing
  leaves the machine.

## Visual direction
Developer tool, calm, fast to scan. Dark default. Monospace for code/branch/paths;
clean sans for chrome. Match my digest brand: paper/ink palette, single warm accent
`#ff4500`, `JetBrains Mono`. Status colors: neutral = idle, amber = uncommitted/
mid-task, green = launched/shipped. Dense but breathable — scanning 10 cards + a
metrics strip at 8am. Keyboard-first: arrows between cards, Enter = start fresh day,
`/` = search.

## Deliverables
1. Clickable visual design (HTML/CSS mockup) of: session grid, a card (collapsed +
   expanded), the "Today" metrics panel, launch states, empty/error states.
2. Interaction spec for "Start fresh day" / "ALL".
3. The metrics panel's exact layout + which numbers go where + the headline format.
4. Responsive notes (wide monitor grid → narrow single column).
Keep it implementable as one local page + a small Node server.

---

## Appendix — real sample data (mock against THIS, not lorem ipsum)
Everything below is the **actual** content the dashboard will render today. Use these
real strings/numbers in the mockup so it reflects how it'll really look — including the
messy cases (unknown branch, big dirty tree, duplicate repo names, hook-noise asks).

### A1. The live session list (what `~/.claude/handoffs/*.md` holds right now)
6 parked sessions, newest first — this is the grid's real input:

| slug (file = `<slug>.md`) | last active | branch | uncommitted |
|---|---|---|---|
| `Users-aoreilly-Wraith` | 06-03 11:04 | _(unknown — show a muted "—")_ | 0 |
| `Users-aoreilly-Repos-ai-news-digest` | 06-03 10:49 | `main` | 1 |
| `Users-aoreilly-Repos-force-uk-portal` | 06-02 17:09 | `redesign/marketing-tokens` | **8** |
| `Users-aoreilly-Repos-Wraith` | 06-02 15:01 | `docs/pr-review-light-routing` | 2 |
| `Users-aoreilly-Repos` | 06-02 14:55 | _(unknown — "—")_ | 0 |
| `Users-aoreilly-Repos-claude-code-playbook` | 06-02 14:46 | `main` | 6 |

Real-world wrinkles to design for, visible above:
- **Two "Wraith" cards** (`~/Wraith` and `~/Repos/Wraith`) — derive a readable title from
  the slug but disambiguate (show the tail path) so near-duplicate names don't confuse.
- **Branch can be `?`/empty** (non-git dir or detached) — render a muted em-dash, not "?".
- **Dirty count drives the amber attention signal** — `force-uk-portal` (8) and
  `claude-code-playbook` (6) should read as "needs attention"; the two 0-file cards as calm.

### A2. A real CLEAN-ish card (1 dirty file) — verbatim `Users-aoreilly-Repos-ai-news-digest.md`
```markdown
# Handoff — ai-news-digest — 2026-06-03 10:49
_Auto (stop-handoff). Live state, overwritten each turn._

## State
- Path: `/Users/aoreilly/Repos/ai-news-digest`
- Branch: `main`
- Last commit: e8fd8fa feat(research): keep every email, de-paywall robustly, no silent drops
- Uncommitted: 1 file(s)
​```
?? site/
​```

## Recent asks (oldest→newest)
- Stop hook feedback: [AUTOPILOT - Phase: unspecified] Autopilot not complete. Continue working...
- Stop hook feedback: [AUTOPILOT - Phase: unspecified] Autopilot not complete. Continue working...
- so where are we at, and give me a prompt to continue so i can clear

## Last action
- If the `[AUTOPILOT]` nudge somehow fires again before you clear, ignore it — nothing's running.
```
Design note: the first two "asks" are **hook noise** (`Stop hook feedback: [AUTOPILOT...]`),
not real human asks. The card should visually de-emphasize or filter `Stop hook feedback:`-
prefixed lines so the one real ask ("so where are we at…") stands out.

### A3. A real DIRTY card (uncommitted file block) — verbatim `Users-aoreilly-Repos-Wraith.md`
```markdown
# Handoff — Wraith — 2026-06-02 15:01
## State
- Path: `/Users/aoreilly/Repos/Wraith`
- Branch: `docs/pr-review-light-routing`
- Last commit: 1125ce569 docs: route dev-iteration reviews to wraith-pr-review-light
- Uncommitted: 2 file(s)
​```
?? docs/reports/2026-05-29-pr-cycle-time.md
?? scripts/pr-cycle-time.py
​```

## Recent asks (oldest→newest)
- ok all done?
- so whats the purpose of this
- its not really a money leak, just a usage hemorage, our claude doctor or whatever it is...

## Last action
- When you're ready, the one thing that'll let me move fast: **what are the "areas"?**...
```
This is the **expanded** state to mock: branch, last commit, the file-status block (`??` =
untracked), the ask trail, and a last-action line that ends mid-thought (often a question
back to me — worth highlighting as "this session is waiting on you").

### A4. Preserved deep notes — `<slug>.compact.md` (show under an "older context" expander)
Written by the PreCompact hook, **appended** (multiple snapshots accumulate in one file):
```markdown
## Pre-compaction snapshot — 2026-06-02 14:30 (trigger: auto)
**Files edited this session:**
- `/Users/aoreilly/Repos/ai-news-digest/src/fetchers/local-folder.ts`
- `/Users/aoreilly/Repos/ai-news-digest/src/fetchers/extract-article.ts`

**Ask history this session (oldest→newest):**
- build the research-folder pipeline
- keep every email, don't drop social
---
```

### A5. "Today" metrics panel — example shape (use these as the mock's numbers)
Real numbers vary by day; this is a representative non-empty day to design the panel around.
Label nothing as a grade — it's a pulse.
- **Shipped:** `3 commits · 1 PR opened · 0 merged`
- **Touched:** `7 files · +312 / −89 lines` (across all `~/Repos`)
- **Activity:** `28 edits · 4 test runs (4✓ 0✗) · 96 tool calls`
- **Focus:** `4 active sessions · 3 repos touched · 6 context-switches`
- **Attention:** `1 session waiting on input · 2 dirty trees`
- **Headline:** `3 commits · 1 PR · 3 repos · 1 session waiting`
- **Empty-state (8am, nothing yet):** `Fresh day. 6 sessions parked, 0 commits so far — pick one and go.`
```
