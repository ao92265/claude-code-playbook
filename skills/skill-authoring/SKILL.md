---
name: skill-authoring
description: >
  Best practices for building Claude Code / Claude.ai Skills, distilled from
  Anthropic's official "Complete Guide to Building Skills". Use when creating a
  new skill, writing or fixing a SKILL.md, choosing a folder name or description,
  debugging why a skill over- or under-triggers, or reviewing a skill before
  shipping. Triggers: "build a skill", "write a SKILL.md", "skill best practices",
  "skill frontmatter", "why is my skill not triggering", "/skill-authoring".

  Do NOT use this skill for: invoking an existing skill to do its job, managing the
  skill registry (use the skill manager), or non-skill markdown/docs work.
metadata:
  user-invocable: true
  slash-command: /skill-authoring
  proactive: false
---

# Skill Authoring

How to write a skill that loads at the right time and does the right thing. Source: Anthropic's *Complete Guide to Building Skills for Claude*.

## The mental model: progressive disclosure (3 levels)

1. **Frontmatter (YAML)** — always in the system prompt. Just enough for Claude to decide *when* to load the skill. This is the highest-leverage thing you write.
2. **SKILL.md body** — loaded only when Claude judges the skill relevant. The full instructions.
3. **Linked files** (`references/`, `scripts/`, `assets/`) — loaded on demand. Push detail here to keep the body lean.

Goal: minimal tokens resident, full expertise available when needed.

## Folder structure

```
your-skill-name/        # kebab-case, matches `name`
├── SKILL.md            # required, exact case
├── scripts/            # optional — executable code
├── references/         # optional — docs loaded as needed
└── assets/             # optional — templates, fonts, icons
```

- **`SKILL.md`** — exactly that, case-sensitive. No `skill.md`, `SKILL.MD`.
- **No `README.md` inside the skill folder.** Docs go in SKILL.md or `references/`. (A repo-level README for humans is fine when distributing on GitHub — that lives outside the skill folder.)

## The `description` field (get this right first)

Formula: **[What it does] + [When to use it / trigger phrases] + [Key capabilities]**.

Rules:
- Must state both *what* and *when* (the phrases a user actually says).
- < 1024 characters.
- **No `< >` angle brackets** anywhere in frontmatter — they can inject as tags into the system prompt. Write "followed by a URL", not `<url>`. Write "over 1k RPS", not `>1k`.
- `name`: kebab-case, no spaces/underscores/capitals, matches the folder. Never contains "claude" or "anthropic" (reserved).
- Add explicit trigger phrases and, for broad auto-triggering skills, a negative trigger ("Do NOT use this for…").

Good vs bad:
- ✅ `Analyzes Figma files and generates dev handoff docs. Use when user uploads .fig files, asks for "design specs", or "design-to-code handoff".`
- ❌ `Helps with projects.` (vague, no triggers)
- ❌ `Implements the Project entity model with hierarchical relationships.` (technical, no user triggers)

## Writing the body

- **Specific and actionable.** `Run python scripts/validate.py --input {file}` — not "validate the data".
- **Always include error handling / troubleshooting** (a `## Common Issues` section with concrete fixes).
- **Reference bundled files explicitly:** "Before X, consult `references/api-patterns.md`."
- Keep the body focused; move depth to `references/`.

## Testing (3 areas)

1. **Triggering** — loads on obvious + paraphrased requests; does NOT load on unrelated topics. Write an explicit should-trigger / should-NOT-trigger list.
2. **Functional** — produces correct outputs; scripts succeed; edge cases covered.
3. **Performance** — compare with vs without the skill (tokens consumed, tool/API calls, back-and-forth turns).

Pro tip: iterate on one hard task until it works, *then* extract the skill. Faster signal than broad testing.

## Trigger tuning

- **Under-triggering** (skill doesn't load when it should; users enable it manually) → add detail and keywords to the description, especially technical terms.
- **Over-triggering** (loads for irrelevant queries; users disable it) → add negative triggers, narrow the description.

## Pre-ship checklist + field reference

See `references/checklist.md` for the full field-requirements table and a copy-paste pre-ship checklist.

## Distribution (brief)

Zip the folder → Claude.ai Settings > Capabilities > Skills, or drop in the Claude Code skills directory. For GitHub: public repo, human README at repo root (not in the skill folder), example screenshots. API path needs `container.skills` + the Code Execution Tool beta. Use the `compatibility` frontmatter field for platform-specific requirements.
