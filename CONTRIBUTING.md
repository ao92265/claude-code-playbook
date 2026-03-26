# Contributing to Claude Code Playbook

Thanks for your interest in contributing! This playbook is built on real-world patterns — your experience makes it better.

## What We're Looking For

- **Skills** — Custom slash commands that solve real problems
- **Hooks** — Shell scripts that catch errors automatically
- **Templates** — CLAUDE.md files for new stacks or frameworks
- **Documentation** — Patterns, troubleshooting guides, examples
- **Bug fixes** — Typos, broken links, incorrect instructions

## Contributing a Skill

1. Create a folder in `skills/` with a descriptive name (kebab-case)
2. Add a `SKILL.md` file with this structure:

```yaml
---
name: your-skill-name
description: >
  What it does in 2-3 sentences. When to use it (triggers).
  When NOT to use it (anti-triggers).
metadata:
  user-invocable: true
  slash-command: /your-skill-name
  proactive: false
---
```

3. Follow with a markdown body containing `## Steps` and `## Important` sections
4. **Keep it generic** — no company names, project names, or user-specific paths
5. Test it in your own Claude Code session before submitting

## Contributing a Hook

1. Add the script to `hooks/`
2. Follow the existing pattern:
   - Read JSON from stdin, extract `file_path` with `jq`
   - Skip early for irrelevant file types
   - Exit 0 (success), 1 (warning), or 2 (error/block)
3. Add a shebang line (`#!/bin/bash`)
4. Update `hooks/README.md` with a new entry documenting:
   - Hook point (PreToolUse, PostToolUse, etc.)
   - Matcher pattern
   - What it catches
   - Prerequisites
5. Test manually: `echo '{"tool_input":{"file_path":"test.ts"}}' | ./your-hook.sh`

## Contributing a Template

1. Add to `templates/` as `CLAUDE-{stack}.md`
2. Follow the existing structure:
   - Each section starts with `##` heading
   - HTML comments (`<!-- -->`) explain what each section does and why
   - Must include at minimum: Project Basics, Testing, Verification, Git & GitHub
3. Stack-specific sections should cover the most common failure modes for that stack
4. Keep advice actionable — "do X" not "consider doing X"

## Contributing Documentation

1. Add to or update files in `docs/`
2. Writing style:
   - Practical over theoretical — show what to do, not just what's possible
   - Include examples and code snippets
   - Format problems as Symptoms/Cause/Fix when applicable
   - Use tables for comparisons and quick references
3. If adding a new doc, update the Documentation table in `README.md`

## Contributing a Plugin

Plugins bundle skills, hooks, and MCP servers into a single distributable package.

1. Create a `plugin.json` manifest — see [Plugin Authoring](docs/plugin-authoring.md) for the schema
2. Include skills, hooks, MCP configs, or rules as needed
3. Add a README explaining purpose, installation, and usage
4. Test installation: `npx skills install ./your-plugin`
5. Include a compatible license (MIT preferred)

## Contributing Examples

1. Add to `examples/` as `{scenario}-session.md`
2. Format as annotated conversation transcripts
3. Use blockquotes (`>`) for annotations explaining what's happening and why
4. Update `examples/README.md` with a description of the new example

## PR Guidelines

- **One feature per PR** — don't bundle a skill, a hook, and a template in one PR
- **Test your changes** — run hooks manually, verify YAML frontmatter parses correctly
- **Remove personal information** — no company names, usernames, file paths, or API keys
- **Keep it generic** — patterns should apply to any team, not just yours
- **Write clear commit messages** — explain what the change does and why

## Code of Conduct

Be kind, be helpful, be constructive. We're all here to make Claude Code better for everyone.
