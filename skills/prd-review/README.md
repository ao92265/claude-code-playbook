# prd-review — a Claude Skill

Reviews and scores a Product Requirements Document. Two layers: a deterministic linter for the
objective structural score, then Claude's semantic deep review (quotes and rewrites the weakest
requirements, catches what regex can't). Output is a graded scorecard, 0-100.

## Install

**Claude Code** — copy this folder into either:
- `~/.claude/skills/prd-review/` (available everywhere), or
- `<project>/.claude/skills/prd-review/` (available in that project).

**claude.ai** — zip the `prd-review/` folder and upload it under Settings → Capabilities → Skills.

## Use

Invoke it with `/prd-review`, or just ask in natural language:

- "review this PRD" / "score docs/prd.md" / "how good is this PRD?"
- paste a PRD and ask for a scorecard.

Claude runs the linter, reads the doc, returns the combined scorecard with rewritten
requirements and the top three fixes, and writes a self-contained **HTML scorecard** you can
share (or publish as an Artifact on claude.ai).

## Run the linter on its own

```bash
python3 scripts/score.py path/to/prd.md                 # auto-detects functional vs design
python3 scripts/score.py path/to/prd.md --mode design   # force design/UX scoring
```

Prints a readable summary plus a `---JSON---` block. Requires Python 3, no dependencies.
It auto-detects **functional** vs **design/UX** PRDs (design PRDs use `UX-FR-*` IDs) and scores
testability + NFRs accordingly; override with `--mode functional|design` if it guesses wrong.

## Files

- `SKILL.md` — the instructions Claude follows.
- `scripts/score.py` — deterministic heuristic linter.
- `scripts/render.py` — turns the review (JSON) into a self-contained HTML scorecard.
- `references/rubric.md` — the six-category scoring rubric Claude judges against.
- `references/report-schema.md` — the JSON shape `render.py` consumes.

The `§` references in findings point at the companion "Writing PRDs" field guide.
