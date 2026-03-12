# The Claude Code Playbook

**Stop prompting. Start engineering.**

A battle-tested collection of skills, hooks, templates, and hard-won lessons from 900+ Claude Code sessions across production TypeScript projects. This isn't theory — it's what actually works when you're shipping code with an AI agent every day.

---

## Why This Exists

Most Claude Code guides tell you how to install it. This one tells you how to *use it well*.

After months of daily production use — debugging at 2am, shipping features across 30+ file changes, managing fleets of sub-agents, and learning the hard way what breaks — we distilled everything into this playbook. The patterns here have been refined through real incidents, real deadlines, and real "why is Claude doing that?" moments.

**What you'll find here:**

- A **667-line power user guide** covering everything from session management to multi-agent orchestration
- **14 production-ready skills** (custom slash commands) you can drop into any project
- A **CLAUDE.md template** that prevents the most common failure modes
- **Hook scripts** that catch errors before they reach your commits
- **Configuration templates** for plugins, MCP servers, and agent teams
- **Lessons from production** — the stuff nobody tells you until something breaks

---

## What's Inside

```
claude-code-playbook/
├── docs/
│   └── guide.md              # The complete power user guide (667 lines)
├── templates/
│   └── CLAUDE.md              # Annotated CLAUDE.md template — copy and customize
├── skills/                    # 14 ready-to-use custom slash commands
│   ├── autoskill/             # Self-learning: extracts patterns from your sessions
│   ├── brainstorming/         # Structured multi-perspective idea exploration
│   ├── check-env/             # Pre-flight checks: ports, Docker, .env, git, credentials
│   ├── codex-prepush-review/  # Automated code review before every push
│   ├── cross-project-search/  # Search across all repos in your workspace
│   ├── deep-explore/          # Deep multi-step codebase exploration
│   ├── dependency-audit/      # Audit deps for vulnerabilities and updates
│   ├── deploy/                # Safe deployment with OOM prevention and confirmations
│   ├── executing-plans/       # Execute written plans with checkpoints
│   ├── karpathy-guidelines/   # Anti-overcomplication checklist (inspired by Karpathy)
│   ├── pr-batch-review/       # Review and manage multiple PRs in one pass
│   ├── skill-creator/         # Meta-skill: create new skills from session patterns
│   ├── verification-before-completion/ # Enforce proof before "done" claims
│   └── writing-plans/         # Structured implementation planning
├── hooks/
│   ├── ts-check.sh            # Auto-run tsc --noEmit on every TypeScript edit
│   └── README.md              # Hook setup guide with exit codes and examples
├── config/
│   └── settings-example.json  # Example ~/.claude/settings.json with plugins + hooks
└── LICENSE                    # MIT
```

---

## Quick Start

### 1. Get the CLAUDE.md template into your project

```bash
# Clone the playbook
git clone https://github.com/ao92265/claude-code-playbook.git

# Copy the template to your project
cp claude-code-playbook/templates/CLAUDE.md /path/to/your/project/CLAUDE.md
```

Edit each section — the template has HTML comments explaining what each rule does and why. Delete the comments once you've customized it. This single file will save you 10-20 minutes per session by encoding your rules once instead of repeating them in every chat.

### 2. Install the skills you want

```bash
# Install a skill globally (available in all projects)
cp -r claude-code-playbook/skills/check-env ~/.claude/skills/

# Or install project-local (only this project)
cp -r claude-code-playbook/skills/deploy /path/to/your/project/.claude/skills/
```

Then use them in Claude Code:
```
> /check-env          # Pre-flight environment check
> /deploy             # Safe deployment with OOM prevention
> /pr-batch-review    # Review all open PRs at once
```

### 3. Set up the TypeScript hook

```bash
cp claude-code-playbook/hooks/ts-check.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/ts-check.sh
```

Add to your `~/.claude/settings.json` (see [hooks/README.md](hooks/README.md) for full setup):
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/ts-check.sh",
        "timeout": 30,
        "statusMessage": "Checking TypeScript types..."
      }]
    }]
  }
}
```

Now every time Claude edits a `.ts` or `.tsx` file, type errors are caught immediately — not 10 minutes later when the build fails.

### 4. Read the guide

Start with **[docs/guide.md](docs/guide.md)** — it covers:

| Section | What You'll Learn |
|---------|-------------------|
| Core Workflow | The Request-Implement-Verify-Close cycle that prevents 90-minute sessions |
| Context Management | Why Claude "gets dumber" mid-session and how to prevent it |
| Reverse Prompting | Let Claude interview *you* for better specs |
| Plugins & MCP | Which plugins are worth installing and which waste context tokens |
| BMAD | Multi-agent orchestration with Architect, Developer, QA, and Security agents |
| OMC | Advanced session modes: autopilot, parallel agents, persistence loops |
| Troubleshooting | Session disconnects, agent deadlocks, OOM crashes |
| Production Lessons | Hard-won patterns from a 10,000+ test codebase |

---

## Skills Reference

Every skill is a drop-in `/command` that teaches Claude a specific workflow. Copy the ones you need.

### Environment & Safety

| Skill | What It Does | When To Use |
|-------|-------------|-------------|
| **[check-env](skills/check-env/)** | Checks ports, Docker, .env files, git status, GitHub credentials, Node.js memory | Start of every session |
| **[deploy](skills/deploy/)** | Pre-deploy checklist: OOM-safe build, tests, env vars, git status, explicit confirmation | Before any deployment |
| **[verification-before-completion](skills/verification-before-completion/)** | Forces Claude to prove work is done with actual test/build output | Automatically before "done" claims |

### Code Quality

| Skill | What It Does | When To Use |
|-------|-------------|-------------|
| **[codex-prepush-review](skills/codex-prepush-review/)** | Automated code review triggered before `git push` | Every push |
| **[pr-batch-review](skills/pr-batch-review/)** | Reviews all open PRs in one pass with a consolidated summary table | PR management sessions |
| **[dependency-audit](skills/dependency-audit/)** | Scans dependencies for vulnerabilities, outdated packages, and license issues | Before releases or periodically |
| **[karpathy-guidelines](skills/karpathy-guidelines/)** | Pre-coding checklist to prevent over-engineering and unnecessary complexity | Before starting any feature |

### Planning & Execution

| Skill | What It Does | When To Use |
|-------|-------------|-------------|
| **[writing-plans](skills/writing-plans/)** | Creates structured implementation plans with architecture decisions and risk flags | Before complex features |
| **[executing-plans](skills/executing-plans/)** | Executes written plans in batches with verification checkpoints | After planning is done |
| **[brainstorming](skills/brainstorming/)** | Multi-perspective structured brainstorming with devil's advocate analysis | When exploring approaches |

### Research & Discovery

| Skill | What It Does | When To Use |
|-------|-------------|-------------|
| **[deep-explore](skills/deep-explore/)** | Multi-step codebase exploration across many files with structural analysis | Understanding unfamiliar code |
| **[cross-project-search](skills/cross-project-search/)** | Searches across all repos in your workspace for patterns and implementations | Finding examples across projects |

### Meta / Self-Improvement

| Skill | What It Does | When To Use |
|-------|-------------|-------------|
| **[autoskill](skills/autoskill/)** | Analyzes your sessions to extract patterns and create new skills automatically | After sessions with lots of corrections |
| **[skill-creator](skills/skill-creator/)** | Meta-skill for creating, testing, and refining new skills | When you need a new custom workflow |

---

## Key Patterns from the Guide

These are the highest-impact patterns from [the full guide](docs/guide.md):

### Separate Planning from Execution
Planning context pollutes implementation focus. If Claude must remember three rejected approaches while writing code, it produces defensive, over-engineered implementations. Plan in one session, execute in another.

### Context Pollution is the #1 Performance Killer
When Claude "gets dumber" mid-session, it's usually context pollution — failed approaches, debug output, and abandoned ideas degrading performance. Use `/clear` when switching tasks. Use `/compact` when context exceeds 50%. Start fresh above 80%.

### Reverse Prompting Gets Better Specs
Instead of writing detailed specs, say: *"Ask me 20 clarifying questions about how this feature should work before you start."* Claude's questions reveal edge cases you hadn't considered.

### The Replace-Don't-Append Rule
Never append to shared context files. Always replace the entire content and keep it under 30 lines. Files that grow unbounded will silently exceed the context window, and Claude drops them without warning.

### Multi-Agent Safety
- No `git stash` in sub-agents (corrupts the working tree for the parent)
- No branch switching (confuses every other running agent)
- Scope commits tightly (never `git add -A` in multi-agent contexts)
- Cap at 3-4 parallel agents to avoid rate limits

---

## The CLAUDE.md Template

The [template](templates/CLAUDE.md) includes these sections, each addressing a specific failure mode discovered in production:

| Section | What It Prevents |
|---------|-----------------|
| **Project Basics** | Wrong language, ESM/CJS import mismatches |
| **UI/Frontend** | Claude assuming visual changes look correct without verification |
| **General Workflow** | Over-planning instead of fixing; filing issues instead of shipping |
| **Agent Usage** | Rate limits and credential failures from too many parallel agents |
| **Token Efficiency** | Burning tokens on Opus when Haiku would suffice |
| **Change Philosophy** | Over-engineering, premature abstractions, scope creep |
| **Verification** | Claiming "done" without running tests or builds |
| **Lessons Tracking** | Repeating the same mistakes across sessions |
| **Communication Rules** | Claude blaming your environment instead of checking actual state |
| **Dev Environment** | Port conflicts, missing env vars, Docker issues discovered mid-session |
| **Build & Deploy** | Node.js OOM crashes during builds |
| **Git & GitHub** | Unsolicited pushes, force-pushes, or PR creation |

---

## Hooks

Hooks are shell scripts that run at specific points during a Claude Code session. They enforce rules automatically so you don't have to repeat yourself.

The included **[ts-check.sh](hooks/ts-check.sh)** hook runs `tsc --noEmit` every time Claude edits a TypeScript file. It catches type errors immediately instead of letting them accumulate.

See **[hooks/README.md](hooks/README.md)** for:
- All available hook points (`PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`, etc.)
- How to write custom hooks with JSON stdin parsing
- Exit code meanings (0 = pass, 1 = warn, 2 = block)
- Configuration examples for `settings.json`

---

## Production Metrics

These numbers are from a real production project that used the patterns in this playbook:

| Metric | Before Claude Code | After |
|--------|-------------------|-------|
| Feature implementation | 2-3 weeks | 4-7 hours |
| Bug fix (triage to prod) | 3-5 days | 30-45 minutes |
| Regressions from AI code | N/A | Zero (all caught in testing) |
| Test suite | ~200 tests | 10,000+ tests passing |
| TypeScript errors | Frequent | Zero |
| ESLint errors | Frequent | Zero |

---

## Contributing

Found a useful pattern? Built a skill that saved you hours? PRs welcome.

**To contribute a skill:**
1. Create a folder in `skills/` with a `SKILL.md` file
2. Use YAML frontmatter with `name`, `description`, and `metadata`
3. Ensure it's generic — no company names, project names, or user-specific paths
4. Submit a PR with a brief description of when and why to use it

**To contribute a hook:**
1. Add the script to `hooks/`
2. Update `hooks/README.md` with setup instructions
3. Document the matcher, exit codes, and use case

**To contribute patterns or lessons:**
1. Add to `docs/guide.md` under the appropriate section
2. Include context on *why* the pattern matters, not just *what* to do

---

## License

MIT — use it, fork it, adapt it, share it.
