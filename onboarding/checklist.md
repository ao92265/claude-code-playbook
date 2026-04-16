---
title: Checklist
nav_order: 6
parent: Onboarding
---
# Onboarding Checklist

Complete these items to confirm you're ready for daily Claude Code use.

---

## Setup

- [ ] Claude Code installed and running (`claude --version`)
- [ ] CLAUDE.md in your project root (customized for your stack)
- [ ] Skills installed globally (`ls ~/.claude/skills/`)
- [ ] Hooks installed and configured (`ls ~/.claude/hooks/`)
- [ ] `~/.claude/settings.json` has hooks configured

## First Session

- [ ] Ran `/check-env` successfully — no blocking issues
- [ ] Used `/explain` on at least one file in your project
- [ ] Fixed a bug or made a change with test verification
- [ ] Created a handoff with `/handoff` — reviewed SESSION_NOTES.md
- [ ] Used `/context` to check context usage

## Skills Practiced

- [ ] `/check-env` — environment validation
- [ ] `/test-first` — wrote a test before implementation
- [ ] `/code-review` — reviewed your own changes
- [ ] `/handoff` — created a session summary
- [ ] `/explain` — got a code explanation

## Concepts Understood

- [ ] One task per session (why multi-task sessions fail)
- [ ] Paste real errors (don't describe, paste the stack trace)
- [ ] Scope-lock prompts ("Only modify src/auth/")
- [ ] Verify with real tests (run them, don't just inspect code)
- [ ] Context management (`/compact` at 50%, fresh session at 80%)
- [ ] Hooks run automatically (type checks, lint, secret detection)

## Optional (Advanced)

- [ ] Tried `/debug` for a real bug
- [ ] Tried `/refactor` with zero behavior change
- [ ] Understand model routing (Haiku / Sonnet / Opus)
- [ ] Read the [anti-patterns guide](../docs/anti-patterns.md)
- [ ] Bookmarked the [workflow decision tree](../docs/workflows.md)

---

**You're ready.** Start using Claude Code for real work. Refer back to the [playbook docs](../docs/) when you need guidance.

Questions? Ask your team's Claude Code champion, or [open a discussion](https://github.com/ao92265/claude-code-playbook/discussions).
