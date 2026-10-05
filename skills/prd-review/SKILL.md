---
name: prd-review
description: >-
  Review and score a Product Requirements Document. Runs a deterministic linter for
  an objective structural score, then does a semantic deep review — quoting the weakest
  requirements and rewriting them, catching implementation leakage, unmeasurable NFRs and
  missing edge cases that regex can't. Produces a graded scorecard (0-100) across structure,
  requirement quality, testability, measurable NFRs, governance and anti-patterns. Use when
  the user asks to review, score, validate, grade, critique or sanity-check a PRD, product
  spec, or requirements doc, or asks "how good is this PRD".
license: MIT
---

# PRD Review

Two layers, one scorecard. A bundled linter gives the objective, repeatable structural
score; you then add the judgement a linter cannot — reading the requirements for meaning,
quoting the weak ones, and rewriting them. **You run the deep review yourself; do not just
hand back a prompt.**

> The bundled scripts live in this skill's `scripts/` directory. `$SKILL_DIR` below is that
> skill's base directory (the absolute path shown when the skill loads) — substitute it.

## 1. Get the PRD

- If the user gave a file path, use it.
- If they pasted text, write it verbatim to a temp file (e.g. `/tmp/prd-review-input.md`).
- If neither, ask for the path or the text before continuing.

## 2. Run the deterministic linter

```bash
python3 "$SKILL_DIR/scripts/score.py" <path>      # or: … score.py -   (reads stdin)
```

It prints a readable summary and a `---JSON---` block with per-category scores, findings
and counts. This is the **structural baseline**. It reliably catches mechanical failures:
missing sections, absent requirement IDs, no acceptance criteria, unmeasurable NFRs,
subjective adjectives, vague quantifiers, implementation leakage. Treat its numbers as the
starting point, not the verdict.

**Modes.** The linter auto-detects **functional** vs **design/UX** PRDs (it keys off UX-prefixed
IDs like `UX-FR-*`) and prints which mode it used. Functional mode scores testability as Gherkin
acceptance criteria and NFRs as latency/uptime/size targets; design mode scores testability as a
definition-of-done + checkable design metrics and NFRs as accessibility/token targets. If it
guesses wrong — e.g. a design PRD that doesn't use `UX-` IDs — re-run with `--mode design` or
`--mode functional`. Confirm the printed mode fits the document before trusting the numbers.

## 3. Read the PRD and read the rubric

Read the whole PRD yourself, and read `references/rubric.md`. The rubric is the standard you
score against — the six categories, their weights, and what a strong entry looks like in each.

## 4. Do the semantic deep review

This is the part only you can do. For each category, sanity-check the linter's score and
**adjust it with a one-line reason** where the linter is fooled or blind. Specifically look for:

- **Capability vs implementation.** An FR that names a mechanism ("sends a JWT", "writes to
  Redis") is leaking implementation even if it has a clean ID. The linter only catches a fixed
  word list.
- **Fake measurability.** An NFR with a number that isn't actually a target ("supports 1 admin
  user") passes the regex but fails the intent.
- **Testability the linter misreads.** A PRD may cover testability with a coverage/traceability
  map instead of Gherkin — credit it. Conversely, Gherkin that only ever tests the happy path
  is thin; dock it for missing the empty / denied / already-done cases.
- **Requirements not traced to a goal**, contradictions, and vague requirements that are
  technically ID'd but untestable.
- **Check the mode.** Confirm the linter picked the right mode for the document type. A
  functional score on a design PRD (testability zeroed for lack of Gherkin) — or the reverse — is
  the first thing to correct, by re-running with the right `--mode`.

Then quote the **3-5 weakest individual requirements verbatim** and rewrite each one so it is a
capability, measurable, and has an acceptance criterion. Show the before and the after.

## 5. Produce the scorecard

Output this structure (Markdown):

```
# PRD review — <PRD title>

**<NN>/100 · Grade <A-E>** — <one-line verdict>
Structural baseline <MM>/100 from the linter, adjusted to <NN> because <reason, or "no change">.

| Category | Score | Note |
|---|---|---|
| Structure & anatomy            | x/20 | … |
| Requirement quality            | x/22 | … |
| Testability (acceptance criteria) | x/16 | … |
| Measurable NFRs                | x/12 | … |
| Decisions & governance         | x/18 | … |
| Anti-pattern cleanliness       | x/12 | … |

## Weakest requirements, rewritten
1. **Before:** "<verbatim>"
   **After:** "<rewrite: capability + measurable + acceptance criterion>"
   Why: <one line>
(3-5 of these)

## Top 3 fixes, highest value first
1. …
2. …
3. …

## All findings
<the linter's findings plus the ones you added, grouped fail / warn / pass, each with its § ref>
```

## 6. Write the shareable HTML scorecard

Turn the review into a self-contained page so it can be shared, not just read in chat. Do this
by default unless the user only wanted a quick number.

1. Assemble a report object per `references/report-schema.md` — the final scores, the category
   notes, the rewrites, the top fixes, and the findings (the linter's plus the ones you added).
2. Write it to a temp file and render:
   ```bash
   python3 "$SKILL_DIR/scripts/render.py" /tmp/prd-report.json <prd-dir>/<name>-scorecard.html
   ```
   `render.py` produces a self-contained, offline, theme-aware HTML scorecard (ring, category
   bars, before/after rewrites, top fixes, findings). It escapes all text — pass plain strings.
3. Tell the user the path. If they are on Claude Code web / claude.ai, offer to publish it as an
   Artifact so they get a shareable link.

## Rules

- **Run, don't defer.** The user wants the review performed, not a prompt to run later.
- **Quote verbatim** when citing a weak requirement, then rewrite. No paraphrasing the original.
- **Explain every adjustment** to the linter's score. If you leave a category as-is, the linter
  number stands.
- **Grade honestly.** A>=90, B>=80, C>=70, D>=55, E<55. A high score means well-formed and
  buildable, not "the right product" — say so if the product judgement is out of scope.
- The `§` references point at the companion PRD field guide's sections.
