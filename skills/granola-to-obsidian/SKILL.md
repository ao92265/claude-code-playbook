---
name: granola-to-obsidian
description: Pull meeting notes from Granola and write them into the Obsidian Work vault. Always use this skill for a Granola to vault capture rather than writing the vault by hand, it carries the current paths and rules. Explicit invoke: /granola-to-obsidian.
---

# Granola → Obsidian

Write Granola meeting notes into the Obsidian Work vault as properly formatted markdown.

## Paths

- **Vault:** `~/Library/CloudStorage/OneDrive-example-corp/Work`
- **Destination:** `01-Active/Meetings/` (chosen by user 2026-07-07; do not relocate without asking)
- **Vault rules:** read the vault's `CLAUDE.md` before writing — YAML frontmatter, kebab-case filenames, lowercase hyphenated tags, `[[wikilinks]]`, never touch `.obsidian/`

## Prerequisites

Granola MCP is registered at user scope (`https://mcp.granola.ai/mcp`, HTTP transport).

1. Load tools first: `ToolSearch` query `+granola` (expect `list_meetings`, `get_meetings`, `query_granola_meetings`, `get_meeting_transcript`, `get_account_info`).
2. If tools are missing or calls return auth errors: tell the user to run `/mcp` → select **granola** → authenticate (browser OAuth, one-time). Do not retry until they confirm.
3. Free-plan limits: last 30 days only; `get_meeting_transcript` and folders are paid-plan-only. Only fetch transcripts when the user explicitly asks.

## Workflow

1. **Identify meeting(s).** Default = today's meetings. Otherwise match the user's description (title/date/attendee) via `list_meetings`. Ambiguous match → ask, don't guess.
2. **Fetch content** via `get_meetings` (enhanced + private notes). Never invent content that isn't in the Granola notes.
3. **Dedup check.** Grep `01-Active/Meetings/` frontmatter for the meeting's `granola-id` before writing. Exists → update that file (append/refresh sections), never create a duplicate.
4. **Write the note** using the template below. Filename: `YYYY-MM-DD-<kebab-title>.md`.
5. **Attendee links.** Wikilink an attendee only if a matching `.md` note already exists in the vault (grep first). Otherwise plain text — never create person notes from this skill.
6. **Report.** List file paths written, one-line summary each. Batch runs use a ledger: `[X/N written, Y updated, Z skipped]`.

## Note template

Mirrors the vault's `03-Knowledge/Templates/Meeting.md`. Map Granola's sections onto these headings; omit sections Granola has nothing for (keep Action Items even if empty).

```markdown
---
title: "<Meeting Title>"
date: YYYY-MM-DD
attendees: [Name One, Name Two]
tags: [type/meeting, status/active]
granola-id: <granola meeting id>
source: granola
---

# <Meeting Title> — YYYY-MM-DD

**Attendees:** Name One, Name Two

## Agenda

## Discussion

## Decisions

## Action Items

- [ ]

## Next Steps

## Links

- [[related-note]]
```

## Guardrails

- Notes land ONLY under `01-Active/Meetings/`. New folder anywhere else = ask first (vault rule).
- Private notes from Granola go in the note body like any other content — but never write secrets/tokens/passwords that appear in transcripts (redact per global rules).
- Don't modify unrelated vault notes; this skill writes/updates meeting notes only.
