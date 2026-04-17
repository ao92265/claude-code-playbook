---
name: changelog
description: >
  Generate a changelog entry from recent commits. Categorizes changes by type
  (features, fixes, breaking changes) and formats as Keep a Changelog style.
  Triggers: "changelog", "generate changelog", "what changed", "release notes".

  Do NOT use this skill for: writing commit messages, reviewing PRs, or documenting
  architecture decisions. Only for generating formatted changelogs.
metadata:
  user-invocable: true
  slash-command: /changelog
  proactive: false
title: "Changelog Generation"
parent: Skills & Extensibility
---
# Changelog Generation

Generate a formatted changelog entry from recent git commits.

## Steps

1. **Determine the range:**
   - Find the last tag: `git describe --tags --abbrev=0 2>/dev/null`
   - If no tags exist, use the last 20 commits
   - Ask the user if they want a different range

2. **Collect commits:**
   - `git log <last-tag>..HEAD --oneline --no-merges`
   - If using conventional commits, parse prefixes (feat:, fix:, docs:, chore:, etc.)
   - If not using conventional commits, categorize by analyzing the commit message content

3. **Categorize changes:**
   - **Added** — new features (feat:, add, new, introduce)
   - **Changed** — modifications to existing functionality (update, modify, refactor, improve)
   - **Fixed** — bug fixes (fix:, resolve, correct, patch)
   - **Removed** — removed features or deprecated code (remove, delete, drop, deprecate)
   - **Security** — security-related changes (security, vulnerability, CVE)
   - **Breaking Changes** — anything that breaks backward compatibility (BREAKING, breaking:)

4. **Format the entry:**
   - Use [Keep a Changelog](https://keepachangelog.com/) format
   - Date in ISO format (YYYY-MM-DD)
   - Group by category with bullet points
   - Include PR/issue references if present in commit messages

5. **Write to CHANGELOG.md:**
   - If file exists, insert new entry at the top (after the header)
   - If file doesn't exist, create it with the standard header
   - Preserve all existing entries — never modify past entries

6. **Show the user for review:**
   - Display the new entry
   - Wait for confirmation before committing

## Important

- **Never modify existing changelog entries** — only add new ones at the top.
- **Preserve the user's commit style** — if they don't use conventional commits, don't force it.
- **Include attribution** — if commits reference PRs or contributors, include them.
- **Ask before committing** — the changelog is the user's release narrative.
