---
title: Installation
nav_order: 1
parent: Onboarding
---
# Step 1: Installation (15 minutes)

## Prerequisites: Claude Account

You need an active Claude account before installing. If you don't have one, sign up at [claude.ai](https://claude.ai) and choose a plan. See the [Account Setup guide](../docs/account-setup.md) for plan comparisons and recommendations.

## Install Claude Code

If you haven't already, install Claude Code:

```bash
npm install -g @anthropic-ai/claude-code
```

Verify it works:

```bash
claude --version
```

## Install the Playbook

Run the interactive installer:

```bash
curl -sL https://raw.githubusercontent.com/ao92265/claude-code-playbook/main/scripts/install.sh | bash
```

When prompted:
1. **Template:** Choose the one matching your project's stack
2. **Skills:** Select "All skills" (option 4) — you can remove unused ones later
3. **Hooks:** Select "All hooks" (option 4)

## Verify Installation

Check that everything is in place:

```bash
# Skills installed?
ls ~/.claude/skills/
# Should show: check-env, deploy, handoff, test-first, etc.

# Hooks installed?
ls ~/.claude/hooks/
# Should show: ts-check.sh, lint-check.sh, env-guard.sh, etc.

# CLAUDE.md in your project?
cat CLAUDE.md | head -5
# Should show your project template
```

## Configure Hooks

Copy the full hooks configuration:

```bash
# If you don't have settings.json yet:
cp path/to/playbook/config/settings-full.json ~/.claude/settings.json

# If you already have settings.json, merge the hooks section manually
```

## What You Just Set Up

- **CLAUDE.md** — Your project's rules and conventions. Claude reads this at the start of every session.
- **Skills** — Custom `/commands` like `/check-env`, `/deploy`, `/test-first`. Type them during a session.
- **Hooks** — Automatic checks that run after every edit (type checking, linting, secret detection).

---

**Next: [02-first-session.md](02-first-session.md)** — Your guided first session
