---
title: FAQ
nav_order: 41
---
# Frequently Asked Questions

Quick answers to the most common questions about Claude Code and this playbook.

---

### What is Claude Code?

Claude Code is Anthropic's CLI tool for working with Claude directly in your codebase. It reads your files, understands your patterns, and implements changes in a session-oriented workflow.

### What is this playbook?

A collection of battle-tested patterns, skills, hooks, templates, and documentation for getting the most out of Claude Code. It's based on 900+ production sessions.

---

## Getting Started

### Do I need to use everything in this playbook?

No. Start with a CLAUDE.md template and one or two skills. Add more as you discover friction in your workflow. See the [getting started guide](getting-started.md).

### What's the minimum I should set up?

1. Copy a CLAUDE.md template to your project root
2. Install the `check-env` skill
3. Set up the `ts-check.sh` hook (for TypeScript projects)

That's it. Three files, five minutes. Everything else is optional.

### How do I install skills?

```bash
# Global (all projects)
cp -r skills/check-env ~/.claude/skills/

# Project-local
cp -r skills/deploy .claude/skills/
```

Or use the interactive installer: `curl -sL https://raw.githubusercontent.com/ao92265/claude-code-playbook/main/scripts/install.sh | bash`

---

## Session Management

### Why does Claude "get dumber" during long sessions?

Context pollution. As your conversation grows, earlier messages (including failed approaches, debug output, and rejected ideas) compete for Claude's attention. Quality degrades gradually.

**Fix:** Use `/clear` when switching tasks. Use `/compact` at 50% context. Start a fresh session above 80%.

### How long should a session be?

One task, one session. If you can describe the task in one sentence, it's a good session scope. Multi-task sessions have lower success rates.

### When should I start a new session vs. use `/compact`?

- **`/compact`** (at 50%): Compresses context while keeping key information. Good for continuing the current task.
- **New session** (above 80%): Start fresh. Write a `/handoff` note first so the new session has context.

### Should I plan and code in the same session?

No. Planning context (rejected approaches, trade-off discussions) pollutes implementation focus. Plan in session 1, save to a file, implement in session 2.

---

## Skills & Hooks

### What's the difference between a skill and a hook?

- **Skills** are invoked manually with `/command-name`. They teach Claude a specific workflow (e.g., `/deploy` runs a deployment checklist).
- **Hooks** run automatically on events (e.g., after every file edit, TypeScript types are checked). You don't invoke them — they fire on their own.

### Can I create my own skills?

Yes. Create a folder in `.claude/skills/` (project-local) or `~/.claude/skills/` (global) with a `SKILL.md` file. See [CONTRIBUTING.md](../CONTRIBUTING.md) for the format.

### Do hooks slow down my session?

Each hook adds a small delay (typically 1-5 seconds). The `ts-check.sh` hook takes ~2-5 seconds depending on project size. This is almost always worth it — catching a type error immediately saves 10+ minutes compared to finding it during a build.

### Can I use hooks and skills in CI?

Skills are Claude Code specific — they don't run in CI. Hooks can be adapted as git hooks or CI steps, but they're designed for the Claude Code workflow.

---

## Model Selection

### Which model should I use for daily work?

Sonnet 4.6. It handles 80% of coding tasks well. See the [model comparison guide](model-comparison.md) for details.

### When should I use Opus?

Architecture decisions, complex debugging, security audits, and multi-step reasoning. If Sonnet struggles after 2 attempts, escalate to Opus.

### Does model choice matter for sub-agents?

Yes, significantly. Use Haiku for file searches, Sonnet for implementation, Opus only for complex decisions. Smart routing saves 30-50% on costs.

---

## CLAUDE.md

### How long should my CLAUDE.md be?

As long as it needs to be, but every line should prevent a specific failure mode. The general template has 12 sections (~80 lines). Remove sections that don't apply to your project.

### Should CLAUDE.md go in the repo?

Yes. Check it in. It's project documentation — other developers using Claude Code benefit from the same conventions.

### What goes in CLAUDE.md vs. a skill?

- **CLAUDE.md:** Rules and conventions (what to do and not do). Read automatically at session start.
- **Skills:** Workflows and processes (step-by-step procedures). Invoked manually when needed.

---

## Multi-Agent

### How many agents can I run in parallel?

Cap at 3-4. Beyond that, API rate limits, credential contention, and memory pressure cause failures.

### Do agents share context?

No. Each agent starts fresh with the CLAUDE.md context and its task prompt. They don't see each other's work unless you explicitly merge results.

### What are worktrees?

Git worktrees are separate working directories that share the same repository. Each agent works in its own worktree so they can't overwrite each other's files. The parent agent merges results.

---

---

## Enterprise & CI/CD

### How do I use Claude Code in my CI/CD pipeline?

Use the official `anthropics/claude-code-action@v1` GitHub Action. It supports automated PR review, `@claude` triggers in comments, and issue-to-PR automation. See the [GitHub Actions guide](github-actions.md).

### How do I set up Claude Code for a large team?

Start with the [Team Setup guide](team-setup.md) for rollout. For 50+ developers or when you need SSO, managed policies, and audit trails, see the [Enterprise Governance guide](enterprise-governance.md).

### How do I fix security vulnerabilities at scale?

Export findings from your scanner (Checkmarx, Snyk, etc.), then use Claude Code with OWASP fix patterns — one finding per session. See the [Security Remediation guide](security-remediation.md).

### How do I create a Claude Code plugin?

Bundle skills, hooks, and MCP servers into a distributable plugin with a `plugin.json` manifest. See the [Plugin Authoring guide](plugin-authoring.md).

### What are Agent Teams?

An experimental feature (Feb 2026) that runs multiple independent Claude Code sessions coordinating via shared task lists and messaging. See the [Agent Teams guide](agent-teams.md).

## Troubleshooting

### Claude is modifying files I didn't ask about

Add scope constraints to your prompt: "Only modify files in `src/auth/`." Or add to CLAUDE.md: "Make the smallest change that works."

### My hooks aren't triggering

1. Check `matcher` in settings.json matches the tool name exactly
2. Verify the hook script is executable: `chmod +x hook.sh`
3. Test manually: `echo '{"tool_input":{"file_path":"test.ts"}}' | ./hook.sh`

### Skills don't appear in Claude Code

1. Verify the SKILL.md has valid YAML frontmatter (starts and ends with `---`)
2. Check the file is in `~/.claude/skills/name/SKILL.md` or `.claude/skills/name/SKILL.md`
3. Restart the Claude Code session

### The build OOMs

Use `NODE_OPTIONS='--max-old-space-size=4096' npm run build`. If it still OOMs, escalate to 8192. The `build-check.sh` hook does this automatically.

See [troubleshooting.md](troubleshooting.md) for 15 more common issues with solutions.
