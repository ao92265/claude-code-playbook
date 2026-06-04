# Skill field reference + pre-ship checklist

L3 detail for `skill-authoring`. Read when finalizing a skill.

## Frontmatter field requirements

| Field | Req? | Rules |
|---|---|---|
| `name` | required | kebab-case only; no spaces/underscores/capitals; matches folder name; never contains "claude" or "anthropic" (reserved) |
| `description` | required | includes WHAT it does + WHEN to use (trigger conditions); < 1024 chars; no `< >` angle brackets; mention specific user phrases; mention file types if relevant |
| `license` | optional | e.g. MIT, Apache-2.0 — if open-sourcing |
| `compatibility` | optional | 1–500 chars; environment/platform requirements (product, system packages, network) |
| `metadata` | optional | custom key-values; suggested: `author`, `version`, `slash-command`, `proactive` |

Security: frontmatter sits in Claude's system prompt. Forbidden: `< >` angle brackets; reserved words "claude"/"anthropic" in `name`. Malicious frontmatter content could inject instructions.

## Pre-ship checklist

- [ ] Folder is kebab-case and matches `name`.
- [ ] File is exactly `SKILL.md` (case-sensitive).
- [ ] No `README.md` inside the skill folder.
- [ ] `description` follows [What] + [When/triggers] + [Key capabilities].
- [ ] `description` < 1024 chars, no `< >` anywhere in frontmatter.
- [ ] Explicit trigger phrases included; negative trigger added if the skill auto-fires broadly.
- [ ] Body instructions are specific + actionable (exact commands, not vague verbs).
- [ ] Body has an error-handling / troubleshooting section.
- [ ] Heavy detail pushed to `references/` and linked from the body.
- [ ] Bundled scripts/assets referenced explicitly by path.
- [ ] Triggering tested: should-trigger, should-paraphrase-trigger, should-NOT-trigger.
- [ ] Functional test passes (valid output, scripts succeed, edge cases).
- [ ] (Optional) Performance compared with vs without the skill.

## Recommended SKILL.md skeleton

```
---
name: your-skill
description: [What] + [When/triggers] + [Key capabilities]. Do NOT use for: [...]
---

# Skill Name

## When to invoke
## How to run        (exact commands)
## Decision rules
## Common Issues     (error -> cause -> fix)
## References        (link to references/*.md)
```
