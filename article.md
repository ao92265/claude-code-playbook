# We Open-Sourced Our Claude Code Playbook — 900+ Sessions of Lessons Learned

After 6 months of using Claude Code daily across production TypeScript projects, we've distilled everything that works (and everything that doesn't) into a single open-source repo.

**The repo:** [github.com/ao92265/claude-code-playbook](https://github.com/ao92265/claude-code-playbook)

## The Problem

Most Claude Code guides stop at installation. They don't tell you what happens when Claude "gets dumber" mid-session, when your build OOMs for the third time, or when your parallel agents deadlock and corrupt each other's git state.

We learned all of this the hard way — through late-night production debugging, multi-agent experiments that went sideways, and dashboard redesigns where Claude confidently removed a sidebar that was clearly visible in the mockup we were literally showing it.

## What's In the Playbook

**A 667-line power user guide** covering the full lifecycle: session management, context pollution prevention, reverse prompting, plugins (BMAD, OMC), MCP servers, multi-agent orchestration, and a real case study where feature delivery went from 2-3 weeks to 4-7 hours.

**14 drop-in skills** — custom `/commands` you can copy into any project:
- `/check-env` — pre-flight environment validation before every session
- `/deploy` — safe deployment with OOM prevention and mandatory confirmation
- `/pr-batch-review` — review all open PRs in one consolidated pass
- `/autoskill` — Claude learns your preferences and creates new skills automatically
- `/karpathy-guidelines` — anti-overcomplication checklist before writing code
- And 9 more covering planning, execution, verification, and codebase exploration

**A CLAUDE.md template** with 12 sections, each preventing a specific failure mode we discovered in production — from ESM/CJS mismatches to Claude making unsolicited git pushes.

**Hook scripts** that auto-check TypeScript types on every edit, plus setup docs.

## The Patterns That Matter Most

Three patterns had the biggest impact on our workflow:

**1. Separate planning from execution.** If Claude remembers three rejected approaches while writing code, it produces defensive, over-engineered implementations. Plan in one session, execute in a fresh one.

**2. Context pollution is the #1 performance killer.** When Claude "gets dumber," it's not the model degrading — it's your conversation accumulating failed approaches and debug output. Use `/clear` when switching tasks. Start fresh above 80% context usage.

**3. Cap parallel agents at 3-4.** We learned this after spawning 11 security-fix agents that completed their work across 15 branches but couldn't push due to credential exhaustion. Rate limits are real.

## The Numbers

From a real production project using these patterns:

| Metric | Before | After |
|--------|--------|-------|
| Feature delivery | 2-3 weeks | 4-7 hours |
| Bug fix cycle | 3-5 days | 30-45 minutes |
| Test suite | ~200 tests | 10,000+ passing |
| Regressions from AI code | Unknown | Zero |

## How to Use It

```bash
git clone https://github.com/ao92265/claude-code-playbook.git

# Copy the CLAUDE.md template to your project
cp claude-code-playbook/templates/CLAUDE.md your-project/CLAUDE.md

# Install skills globally
cp -r claude-code-playbook/skills/check-env ~/.claude/skills/
cp -r claude-code-playbook/skills/deploy ~/.claude/skills/
```

Everything is MIT licensed. Fork it, adapt it, contribute back.

## What's Next

We're actively adding more content — prompt engineering patterns, stack-specific templates (React, Node API, Python, fullstack monorepo), additional hook scripts, a troubleshooting guide, and a quick-reference cheat sheet. Watch the repo or submit a PR if you've got patterns worth sharing.

The goal is simple: spend less time fighting Claude and more time shipping.

---

*The playbook was built using Claude Code itself — including this article. The repo creation, content generation, sanitization, and README with 9 Mermaid diagrams were all done in a single session.*
