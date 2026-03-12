# Claude Code Best Practices

A collection of battle-tested Claude Code best practices, skills, hooks, and configuration templates gathered from production use across multiple TypeScript projects.

Whether you're just getting started with Claude Code or looking to level up your team's workflow, this repo provides ready-to-use templates and patterns that have been refined through months of real-world usage.

## What's Inside

| Directory | Description |
|-----------|-------------|
| [docs/guide.md](docs/guide.md) | The complete power user guide covering workflows, plugins, MCP servers, agents, and orchestration |
| [templates/CLAUDE.md](templates/CLAUDE.md) | A generic CLAUDE.md template with annotated sections you can adapt to any project |
| [skills/](skills/) | 14 reusable skill files (custom slash commands) for common workflows |
| [hooks/](hooks/) | Example hook scripts for automated checks (TypeScript validation, etc.) |
| [config/](config/) | Sanitized settings.json example showing hook and plugin configuration |

## Quick Start

### 1. Set up your CLAUDE.md

Copy the template to your project root and customize it:

```bash
cp templates/CLAUDE.md /path/to/your/project/CLAUDE.md
```

Edit the sections to match your project's stack, conventions, and safety rules.

### 2. Install Skills

Copy any skills you want into your global or project-local skills directory:

```bash
# Global (available in all projects)
cp -r skills/autoskill ~/.claude/skills/

# Project-local (only available in this project)
cp -r skills/autoskill /path/to/your/project/.claude/skills/
```

### 3. Set up Hooks

Copy hook scripts and configure them in your settings:

```bash
cp hooks/ts-check.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/ts-check.sh
```

Then add the hook to `~/.claude/settings.json` — see [hooks/README.md](hooks/README.md) for details.

### 4. Read the Guide

Start with [docs/guide.md](docs/guide.md) for a comprehensive walkthrough of Claude Code workflows, from basic session management to multi-agent orchestration.

## Skills Reference

| Skill | Description |
|-------|-------------|
| [autoskill](skills/autoskill/) | Learns team preferences from coding sessions and updates skills automatically |
| [brainstorming](skills/brainstorming/) | Structured brainstorming with multi-perspective analysis |
| [check-env](skills/check-env/) | Pre-flight environment checks (ports, Docker, .env, git status) |
| [codex-prepush-review](skills/codex-prepush-review/) | Automated code review before git push |
| [cross-project-search](skills/cross-project-search/) | Search across multiple repositories simultaneously |
| [deep-explore](skills/deep-explore/) | Deep codebase exploration with structural analysis |
| [dependency-audit](skills/dependency-audit/) | Audit project dependencies for issues and updates |
| [deploy](skills/deploy/) | Safe deployment checklist with mandatory confirmations |
| [executing-plans](skills/executing-plans/) | Structured plan execution with verification steps |
| [karpathy-guidelines](skills/karpathy-guidelines/) | Software engineering guidelines inspired by Andrej Karpathy's principles |
| [pr-batch-review](skills/pr-batch-review/) | Review multiple PRs in batch |
| [skill-creator](skills/skill-creator/) | Meta-skill for creating new skills |
| [verification-before-completion](skills/verification-before-completion/) | Enforce verification before claiming task completion |
| [writing-plans](skills/writing-plans/) | Structured approach to writing implementation plans |

## Contributing

Contributions welcome! If you've developed useful skills, hooks, or patterns for Claude Code, please submit a PR.

## License

MIT
