---
name: autoskill
description: |
  Analyze coding sessions to learn team preferences and update skills. Searches conversation
  history for correction signals where the user stated a preference or corrected an approach.
  Creates or updates skill files with learned patterns. Triggers: "learn from this session",
  "autoskill", "what did you learn", after completing work with corrections.

  Do NOT use this skill for: normal coding tasks, one-off fixes, file searches, or any task
  that doesn't involve reviewing and extracting learnings from session corrections. Don't
  trigger mid-task just because a correction happened — wait until work is complete.
license: MIT
compatibility: marvin
metadata:
  marvin-category: work
  user-invocable: true
  slash-command: /autoskill
  model: default
  proactive: false
title: "Autoskill: Learn from This Session"
parent: Skills & Extensibility
---
# Autoskill: Learn from This Session

## Step 1: Resolve Project Context

1. Extract the project name from `$CWD` (e.g., `/path/to/your/project` → `example-project`).
2. Check whether `.claude/skills/` exists in the project root. If yes, project-local skills are available.
3. Note the three possible skill destinations:
   - Project-local: `.claude/skills/{project}-{category}.md`
   - Global: `~/.claude/skills/{project}-{category}.md`
   - Critical rules: project root `CLAUDE.md`

## Step 2: Check for Subcommand

Inspect `$ARGUMENTS`. If a recognized subcommand is present, branch as follows:

- `review` — Execute Steps 3–5 only; skip Steps 6–7. Output proposals, do not apply.
- `history` — Run `git log --oneline --grep="autoskill:"` and display results. Stop.
- `apply` — Skip to Step 6 using any previously proposed but unapplied learnings. Stop after Step 7.
- `global` — Proceed normally but restrict signal search and output to cross-project preferences only.
- No argument — Continue to Step 3.

## Step 3: Search for Correction Signals

Call `mcp__historian__search_conversations` with the following query:

```
"no use instead|don't use|we always|we never|our convention|team prefers|standard practice"
```

Also search separately for:
- `"Actually|Wrong|not like that|stop doing"`
- The current project name to filter results to this repo.

Collect all candidate signals. If no signals are found, output "No correction signals detected in recent sessions." and stop.

## Step 4: Filter Each Signal for Quality

For each candidate signal, apply all four checks. If any check fails, discard the signal and move to the next.

1. **Novel?** Would Claude not already know this from general training?
   - If yes (project-specific, team-specific): pass.
   - If no (general best practice): discard.

2. **Durable?** Does it apply beyond this single task or file?
   - If yes ("we always", "never", category-wide): pass.
   - If no ("just this file", "this time only"): discard.

3. **Team-relevant?** Does it benefit the whole project, not just one user preference?
   - If yes: pass.
   - If no: discard.

4. **Actionable?** Can it be written as a concrete rule or anti-pattern?
   - If yes: pass.
   - If no: discard.

After filtering, if no signals remain, output "No qualifying learnings found." and stop.

## Step 5: Map Each Signal to a Skill File

For each surviving signal, select the target file using this table:

| Content category             | Target file pattern                |
| ---------------------------- | ---------------------------------- |
| Backend, API, NestJS, Prisma | `.claude/skills/{project}-backend.md` |
| Frontend, React, components  | `.claude/skills/{project}-frontend.md` |
| Testing patterns             | `.claude/skills/{project}-testing.md` |
| Database, migrations         | `.claude/skills/{project}-database.md` |
| E2E, Playwright              | `.claude/skills/{project}-e2e.md` |
| Git, commits, workflow       | `.claude/skills/{project}-git.md` |
| API integrations             | `.claude/skills/{project}-integrations.md` |
| General project rules        | `CLAUDE.md` (project root) |
| Cross-project preferences    | `~/.claude/skills/global-prefs.md` |

Then assign scope:
- Project convention → `.claude/skills/{project}-{category}.md`
- Personal preference across all repos → `~/.claude/skills/global-prefs.md`
- Critical rule → project `CLAUDE.md`

## Step 6: Propose Updates

For each mapped signal, output one proposal block:

```
## Proposed Update

**File**: `{path}`
**Section**: [relevant section]
**Type**: ADD | MODIFY
**Scope**: PROJECT | GLOBAL

**Content to add**:
> [1-3 line rule or pattern]

**Triggered by**:
> "[Quote the user's correction verbatim]"

**Confidence**: HIGH | MEDIUM | LOW
**Justification**: [One sentence explaining why this belongs in shared skills]
```

## Step 7: Apply Updates

For each HIGH confidence proposal, apply immediately without waiting for approval:

1. If the target file does not exist, create it with a minimal frontmatter header.
2. Read the target file.
3. Locate the appropriate section. If no section matches, create one.
4. Insert the new rule or pattern (1–3 lines only; do not rewrite surrounding content).
5. Display the diff.

For MEDIUM or LOW confidence proposals, display the proposal and wait for explicit user approval before editing.

After applying, if the directory is a git repo, commit:

```bash
git add .claude/skills/{file}.md
git commit -m "autoskill: learned [specific thing]

Signal: [what triggered this]"
```

## Constraints

- Add 1–3 lines per learning. Do not rewrite existing sections.
- Preserve existing file formatting and structure.
- Only record novel, project-specific knowledge.
- Never add hooks automatically. This command is manual-invoke only.
