---
title: Auditing & Hardening Your Setup
nav_order: 43
parent: Architecture
---
# Auditing & Hardening Your `~/.claude` Setup

A power-user `~/.claude` accretes cruft: dead MCP servers, plaintext keys, hooks that no-op, maintenance scripts you wrote but never scheduled, and permission config that *reads* safe but isn't. This is a worked case study of auditing one and the transferable fixes that came out of it — every pattern here generalizes.

The trigger was an [Anthropic usage-insights report](usage-insights.md): its top friction was *false-completion claims* and *research-only scope slips*. Reconciling that report against the existing setup showed most of its checkbox suggestions were already implemented — the real work was patching the gaps where existing infra was too weak.

---

## The audit method

Don't eyeball it. Fan out a read-only review across independent dimensions, then verify each finding by reading the actual files:

1. **Hooks** — latency, redundancy, double-fire, dead hooks.
2. **MCP servers** — which are live vs dead weight, context-token cost, secrets in config.
3. **Scheduling** — scripts that *document* a cron line but run nowhere.
4. **Storage** — backup sprawl, what the prune script misses.
5. **Config coherence** — conflicting modes, stale references, drift.
6. **Skills/plugins** — genuine overlap vs complementary tools.
7. **Workflow** — what you do by hand that a hook/loop could do.

The highest-value output isn't the list of problems — it's separating *real* issues from things that are fine-as-designed, so you don't over-optimize. (A verify pass corrected several first-round claims: e.g. an MCP `timeout: 15` is **seconds** (a launcher default), not milliseconds; HTTP servers correctly have a null `command`; a path-keyed self-overwriting `handoffs/` dir is not "sprawl".)

---

## Pattern 1 — Make one hook the single Bash enforcement layer

**The gotcha.** `settings.local.json` with `defaultMode: bypassPermissions` silently voids the entire `autoMode.hard_deny` block in `settings.json`. Your config *reads* protected (`rm -rf`, force-push, prisma all "denied") but nothing enforces it — bypass mode skips permission checks entirely.

**The fix.** Hooks fire regardless of permission mode. Move all the denial logic into a `PreToolUse(Bash)` firewall hook + a `PreToolUse(Edit|Write)` protect-paths hook, then delete the inert `hard_deny` block. Now there's one source of truth that actually runs.

```bash
# firewall.sh — PreToolUse(Bash). Exit 2 = deny. Fires in every permission mode.
case ",${OMC_SKIP_HOOKS:-}," in *,firewall,*) exit 0 ;; esac   # deliberate one-off escape
INPUT=$(cat); CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
[ -z "$CMD" ] && exit 0
# Strip quoted strings so we don't match text inside commit messages.
STRIPPED=$(echo "$CMD" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
# ...block bare 'git reset --hard', recursive-force rm, force-push (-f/--force, allow --force-with-lease),
#    dropdb, prisma migrate deploy/reset, DROP/TRUNCATE TABLE (case-insensitive), cloud destructives...
```

Give it an `OMC_SKIP_HOOKS=firewall` escape hatch so a deliberate one-off doesn't require editing the hook.

### Lesson: test variant spellings, not the canonical one

A separate code-review pass caught **7 bypass holes** the unit tests missed — because the tests checked the canonical spelling and attackers (or a careless paste) use variants:

| Blocked the obvious | Missed the variant |
|---|---|
| `git push --force` | `git push -f` |
| `git reset --hard` (bare) | `git reset --hard HEAD` (the `?` made the suffix optional) |
| `DROP TABLE` | `drop table` (no `-i` on grep) |
| `git clean -fd` | `git clean -dfx`, `git clean -f -d` (flag order) |

When you write a deny-gate, your test matrix must include lowercase, reordered flags, short forms, and flags-after-path (`rm dir -rf`). [Verify-gate hook](verify-gate-hook.md) and [permissions](permissions.md) cover the adjacent layers.

---

## Pattern 2 — Get secrets out of the config file

`~/.claude.json` is rewritten constantly and copied into many timestamped backups, so any plaintext key there lives on in N backups. Indirect through the environment:

```jsonc
// ~/.claude.json  (Claude Code expands ${VAR} from the environment)
"nano-banana": { "command": "npx", "args": ["-y","@fjacquet/nano-banana-mcp"],
                 "env": { "GEMINI_API_KEY": "${GEMINI_API_KEY}" } },
"github":      { "command": "npx", "args": ["-y","@modelcontextprotocol/server-github"],
                 "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}" } }
```

```bash
# ~/.zshrc — source the GitHub token from gh's own auth, no hardcoding:
export GITHUB_PERSONAL_ACCESS_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-$(gh auth token 2>/dev/null)}"
```

Then **rotate** the key that was previously in plaintext — moving it doesn't un-leak it. (Desktop-app launches may not inherit your shell env; this works for CLI sessions.)

---

## Pattern 3 — Research-only must gate Bash, not just edits

A common research-only guard blocks `Edit|Write|NotebookEdit` when a sentinel flag exists — but leaves **Bash** open, so the agent still runs `npm test`, `tsc`, `git commit`. Make the guard tool-aware: register it on the `Bash` matcher too, allow read-only Bash (`git status/log/diff`, `ls`, `cat`, `grep`, `gh pr view`), and block mutating Bash (installs, builds, `git` mutations, redirects, `rm/mv/cp`, script interpreters, `gh` writes).

```bash
flag=".claude/state/research-only.flag"; [ -f "$flag" ] || exit 0
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && { echo "research-only: edits disabled" >&2; exit 2; }   # Edit/Write call
# else: allow read-only Bash, exit 2 on mutating verbs / redirects / interpreters
```

Pair it with a `UserPromptSubmit` detector that arms the flag when the prompt says "research-only" — so typing it works, not only the `/research-only` skill. See [steering files](steering-files.md) for the prose-layer companion rule.

---

## Pattern 4 — Schedule the scripts you already wrote

The biggest single waste found: four maintenance scripts each *documented* a `cron` line in their header but were scheduled nowhere — `cron -l` was empty. On macOS, prefer **launchd** (survives sleep via `StartCalendarInterval`). Ship an idempotent installer that writes the plists and (re)bootstraps:

```bash
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$label.plist"
```

Key plist conventions: `ProgramArguments = ["/bin/zsh","-lc","<script> >> <log> 2>&1"]` (XML-escape the redirect: `&gt;&gt; ... 2&gt;&amp;1`), an explicit `EnvironmentVariables.PATH` (homebrew first — launchd doesn't inherit your shell PATH), and `plutil -lint` each plist before loading. Jobs worth scheduling: a weekly prune, a weekly cost audit ([cost & observability](cost-and-observability.md)), a daily cross-terminal briefing ([day-start dashboard](day-start-dashboard-brief.md)).

---

## Pattern 5 — Turn babysitting into loops

The usage history showed `continue` ×590, `retry` ×88, `keep going` ×35 — and `/loop` ×0, `/goal` ×0. The directive to "use loops" was dead prose. Hook-ify it: a `UserPromptSubmit` hook counts consecutive bare continuations per session and, on the 3rd, injects a non-blocking reminder to restate a done-condition + verify command and hand off to `/loop` (iterate-until-condition) or `/goal` (multi-step + final verify). Same hook can alias `commit this` / `push it` to your commit skill. The rule of thumb from [anti-patterns](anti-patterns.md): a rule ignored three sessions running should become a hook, not more CLAUDE.md text.

---

## Pattern 6 — Verify against live state (no false "done")

The report's #1 friction. Bake these into CLAUDE.md and your PR skills:

- **PRs:** before claiming done / NO-CHANGES-NEEDED, re-fetch live state (`gh pr view --json reviewDecision,reviews,statusCheckRollup`). `CHANGES_REQUESTED` is sticky until the reviewer dismisses; never auto-dismiss it. Push + report READY, let the human merge — don't auto-merge on a blind clock.
- **UI/visual:** never certify a theme fix from your own screenshots; find the root cause in source (orphaned components, stale imports) and ask the human to confirm in a real browser.

---

## Pattern 7 — Close the prune gaps

A prune script that's never run is just a comment. After wiring it to a schedule (Pattern 4), audit *what* it misses. In this case the 60-day `*.jsonl` rule reclaimed almost nothing — the bulk was thousands of stale per-task agent-worktree session directories:

```bash
find projects -maxdepth 1 -type d -name '*agent-worktrees*TASK-*' -mtime +14 -exec rm -rf {} +
find . -maxdepth 1 -name 'settings.json.bak*' -mtime +30 -delete   # backup-file sprawl
```

One run reclaimed ~2,250 directories. Measure `du -sh` before/after so the reclaim is evidence, not a guess.

---

## Verification discipline

Every change was proven, not assumed:

- `hooks-smoke-test.sh` after any hook edit; `jq -e .` on every config file touched.
- ~50 block/allow unit cases for the firewall + research-only guards.
- A **separate** `code-reviewer` pass (different model, fresh context) — which is what caught the 7 variant-bypass holes. Authoring and review must be separate lanes; never self-approve the gate you just wrote.

See also: [verify-gate hook](verify-gate-hook.md) · [permissions](permissions.md) · [auto mode](auto-mode.md) · [cost & observability](cost-and-observability.md) · [30-day usage insights](usage-insights.md).
