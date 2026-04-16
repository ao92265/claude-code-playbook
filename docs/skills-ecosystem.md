---
title: Skills Ecosystem
nav_order: 1
parent: "Skills & Extensibility"
---
# The Agent Skills Ecosystem

The open agent skills ecosystem (`skills.sh`) is a package manager for AI agent skills — modular packages that extend Claude Code (and other agents) with specialized knowledge, workflows, and best practices.

> **Browse:** [skills.sh](https://skills.sh/) | **CLI:** `npx skills`

---

## Quick Start

```bash
# Search for skills
npx skills find "react testing"

# Install a skill (project-local)
npx skills add vercel-labs/agent-skills@react-best-practices -y

# Install globally (all projects)
npx skills add vercel-labs/agent-skills@react-best-practices -g -y

# Check for updates
npx skills check

# Update all installed skills
npx skills update
```

Skills install to `.agents/skills/` (universal) and symlink into `.claude/skills/` for Claude Code.

---

## How Skills Work

Skills are markdown files with frontmatter that teach agents specialized workflows. When installed, they appear as available context — Claude Code reads them when relevant to your task.

```
your-project/
├── .agents/skills/          # Universal skills (all agents)
│   ├── playwright-best-practices/
│   │   └── SKILL.md
│   └── nestjs-best-practices/
│       └── SKILL.md
├── .claude/skills/          # Claude Code symlinks (auto-created)
│   ├── playwright-best-practices -> ../../.agents/skills/...
│   └── nestjs-best-practices -> ../../.agents/skills/...
```

**Key difference from custom skills:** Community skills from `skills.sh` install into `.agents/skills/` and get symlinked. Your own custom skills (like those in this playbook) live directly in `.claude/skills/`.

---

## Finding Skills

### 1. Browse the Leaderboard

Visit [skills.sh](https://skills.sh/) to see skills ranked by total installs. Top skills have 100K+ installs from trusted sources like `vercel-labs`, `microsoft`, and `anthropics`.

### 2. Search by Keyword

```bash
npx skills find "playwright"     # Testing
npx skills find "nestjs"         # Backend framework
npx skills find "tailwind"       # CSS framework
npx skills find "security owasp" # Security
npx skills find "accessibility"  # a11y / WCAG
```

### 3. Use the find-skills Skill

Install the meta-skill that helps discover other skills:

```bash
npx skills add vercel-labs/skills --skill find-skills -y
```

---

## Evaluating Skills Before Installing

Not all skills are equal. Before installing, check:

| Signal | Green Flag | Red Flag |
|:-------|:-----------|:---------|
| **Install count** | 1K+ installs | Under 100 |
| **Source** | `vercel-labs`, `microsoft`, `anthropics`, `github` | Unknown author |
| **Security rating** | "Safe" or "Low Risk" | "Critical Risk" |
| **Repo stars** | 100+ GitHub stars | No public repo |

The Skills CLI shows security risk assessments during installation from three scanners (Gen, Socket, Snyk). Review these before confirming.

---

## Recommended Skills by Stack

### Full-Stack TypeScript (React + Node.js/NestJS)

```bash
# Frontend
npx skills add wshobson/agents@tailwind-design-system -y
npx skills add addyosmani/web-quality-skills@accessibility -y
npx skills add sickn33/antigravity-awesome-skills@web-performance-optimization -y

# Backend
npx skills add kadajett/agent-nestjs-skills@nestjs-best-practices -y
npx skills add wshobson/agents@api-design-principles -y

# Testing
npx skills add currents-dev/playwright-best-practices-skill -y
npx skills add microsoft/playwright-cli -y

# Security
npx skills add hoodini/ai-agents-skills@owasp-security -y

# Deployment
npx skills add microsoft/azure-skills@azure-prepare -y
```

### React / Next.js

```bash
npx skills add vercel-labs/agent-skills@react-best-practices -y  # 241K installs
npx skills add wshobson/agents@tailwind-design-system -y
npx skills add addyosmani/web-quality-skills@accessibility -y
```

### Python / FastAPI

```bash
npx skills find "python fastapi"
npx skills find "pytest"
```

### DevOps / Docker / Azure

```bash
npx skills add microsoft/azure-skills@azure-prepare -y  # 81K installs
npx skills find "docker"
npx skills find "kubernetes"
```

---

## Skills vs MCP Servers vs Plugins

| Feature | Skills | MCP Servers | Plugins |
|:--------|:-------|:------------|:--------|
| **What they are** | Markdown knowledge files | Running processes with tools | Claude Code extensions |
| **Install method** | `npx skills add` | `mcpServers` in config | `enabledPlugins` in settings |
| **Token impact** | Loaded when relevant | Always active (high cost) | Always active |
| **Examples** | Best practices, patterns | GitHub API, browser, DB | OMC, BMAD, Context7 |
| **When to prefer** | Domain knowledge, workflows | External tool access | Orchestration, custom tools |

**Rule of thumb:** If you need *knowledge* (patterns, best practices, workflows), use a skill. If you need *tool access* (APIs, browsers, databases), use an MCP server. If you need *orchestration* (multi-agent, session modes), use a plugin.

---

## Redundancy Cleanup

Community skills can overlap with MCP servers and built-in tools. Before installing, check for redundancy:

| Redundant Setup | Better Alternative |
|:----------------|:-------------------|
| `filesystem` MCP server | Built-in Read/Write/Edit/Glob/Grep tools |
| `memory` MCP server | Auto-memory system (`~/.claude/projects/`) |
| Playwright MCP plugin | `microsoft/playwright-cli` skill + `claude --chrome` |
| Manual `.claude/skills/*.md` for generic patterns | Community skills with updates via `npx skills update` |

Keep custom project-specific skills (like `wraith-backend-module.md`) alongside community skills — they complement each other. Community skills provide general best practices; custom skills encode your project's specific conventions.

---

## Creating Your Own Skills

```bash
# Initialize a new skill
npx skills init my-custom-skill

# Structure
my-custom-skill/
└── SKILL.md    # Frontmatter + instructions
```

A skill is just a markdown file with YAML frontmatter:

```markdown
---
name: my-custom-skill
description: One-line description used for relevance matching
---

# My Custom Skill

Instructions and patterns for the agent to follow...
```

See the [skill-creator](../skills/skill-creator/) skill in this playbook for an interactive workflow.

To bundle multiple skills, hooks, and MCP servers into a distributable plugin, see the [Plugin Authoring guide](plugin-authoring.md).

---

## Tips

- **Install project-local by default.** Global skills (`-g`) apply everywhere — only use for truly universal tools like `find-skills`.
- **Review before use.** Skills run with full agent permissions. Read the `SKILL.md` before installing from unknown sources.
- **Update periodically.** Run `npx skills check` to see if installed skills have updates.
- **Don't over-install.** Each skill adds to context. Install only what's relevant to your stack.
- **Combine with custom skills.** Use community skills for general patterns and custom `.claude/skills/` for project-specific conventions.

---

*Browse the full directory at [skills.sh](https://skills.sh/).*
