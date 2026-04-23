---
name: doc-finalise
description: >
  Finalise a Word (.docx) deliverable with embedded visuals, integrity checks,
  and a paste-ready commit block. Covers status reports, board packs, sprint
  retrospectives, RFCs, and compliance documents where factual accuracy and
  style consistency both matter.
  Triggers: "finalise this doc", "doc-finalise", "wrap the report", "embed the chart", "board pack".

  Do NOT use this skill for: drafting from scratch (use a writer skill), slide decks (.pptx),
  or plain markdown where style inheritance and PDF rendering are not concerns.
metadata:
  user-invocable: true
  slash-command: /doc-finalise
  proactive: false
title: "Document Finalisation"
parent: Skills & Extensibility
---
# Document Finalisation

Structured workflow for finishing a `.docx` deliverable: programmatic integrity check, embedded visuals, style normalisation, PDF regeneration, and a Closeout Trio summary. Built for the case where a reviewer will spot every wandering em-dash and every rounding drift.

## When to Use

- Executive status reports where rounded numbers must be replaced with exact ones.
- Board packs and compliance documents with claim-level provenance requirements.
- Any second-pass edit where "tighten this up" has historically rephrased a number into an inaccuracy.
- Documents where visuals must survive the `.docx` → PDF conversion unchanged.

## When Not to Use

- Drafting the document from scratch — use a writer skill, then finalise with this one.
- Slide decks (`.pptx`) — different library, different gotchas.
- Plain markdown deliverables — style inheritance and PDF rendering are not in scope.

## Steps

1. **Read the docx toolchain reference before touching the file.** Load the Anthropic bundled docx skill (if available) or your project's `python-docx` reference. Do not skip this even if the model thinks it knows the API — the style-map and image-anchor details are where real documents break.

2. **Inventory the source document programmatically.** Capture a baseline so any later claim of "I only changed X" is verifiable.

   | Check | What to capture |
   |---|---|
   | Structure | Paragraph count, table count, section count, page count |
   | Styles | Full style map, every explicit style override on every run |
   | Typography | Em-dash (`—`) and en-dash (`–`) counts across `document.xml`, `header*.xml`, `footer*.xml` |
   | Assets | Every embedded image (id, size, anchor paragraph text) |
   | Theme | Font references — `majorFont` / `minorFont` — and any theme fallback |

3. **Embed visuals as PNG, not linked images.** Linked images break on email handoff and PDF conversion.
   - Use `doc.add_picture()` inside a centred paragraph, not floating anchors.
   - Insert at **named text anchors** — "before the paragraph starting with `Quarterly summary`" — not "around the end of section 3". Paragraph indices shift; sentence fragments do not.
   - Render charts with `matplotlib` at the target font size, save to PNG at 150 DPI minimum, embed from memory.

4. **Normalise style inheritance once.** Set explicit values so run-level overrides become non-conflicting rather than competing.
   - Explicit font name on `Normal` and every heading style.
   - Explicit line spacing on `docDefaults`.
   - Replace theme font references (`majorFont` / `minorFont`) with concrete names so the doc renders the same on a machine without the source theme installed.

5. **Regenerate the PDF and spot-check it, not the docx.** Visuals and fonts can render correctly in Word and badly in the PDF conversion.
   - `libreoffice --headless --convert-to pdf <file>.docx`
   - Rasterise the pages with embedded visuals (`pdftoppm` or `pdf2image`).
   - Compare each visual in the PDF against the original PNG. Size, crop, DPI loss, font substitution — all show up here, not in the docx.

6. **Produce a Closeout Trio summary.** See [prompt-patterns.md §22](../../docs/prompt-patterns.md#22-the-closeout-trio). Include concrete numbers, not prose.

   ```
   What I did
   - 98 paragraphs → 108 paragraphs (+10: two five-element chart blocks)
   - 3 embedded PNGs, 150 DPI, 412/438/391 KB
   - PDF regenerated, 14 pages, visuals verified against source PNGs
   - Em-dash count unchanged across body, headers, footers (47)

   What I could not do and why
   - No repo access — producing files + paste-ready commit block instead

   What needs your eyes
   - Appendix B table row 4 conflicts with prose on page 7 (see anti-pattern 22 — flagged, not resolved)
   - Cover-page colour matches brand guide sample but sandbox has no Calibri installed (see Gotchas)
   ```

7. **If sandboxed without repo access, emit a paste-ready commit block.** Do not fabricate a commit or a push.

   ```
   # Paste-ready commit
   Branch: docs/q3-board-pack
   Message: finalise(q3): embed charts, normalise styles, regen PDF
   Files:
     - reports/q3-board-pack.docx
     - reports/q3-board-pack.pdf
     - reports/assets/chart-revenue.png
     - reports/assets/chart-runrate.png
   ```

## Gotchas

- **Default stack:** `python-docx` + `matplotlib` for anything chart-heavy. The unpack-and-rewrite-XML route is a last resort — it breaks style inheritance and is easy to get subtly wrong. Stick with the library APIs.
- **Font fallback:** sandboxes without Calibri fall back to Liberation Sans. Visually near-identical at chart scale, but different metrics. Do not claim a chart was "rendered in Calibri" unless you verified the font is installed.
- **Accessibility:** `libreoffice --headless --convert-to pdf` emits **tagged PDFs by default**. Relevant when the audience is accessibility-sensitive (screen readers, WCAG). Do not strip tags during any post-processing step.
- **Em-dash and en-dash audit:** these characters travel poorly through copy-paste and some linters auto-"fix" them. A pre/post count across `document.xml`, headers, and footers catches silent drift.
- **Silent conflict resolution:** if two numbers in the same document disagree, flag the conflict — do not pick one. See [anti-patterns.md §22](../../docs/anti-patterns.md).

## Related

- [prompt-patterns.md §21 — SOURCE FACTS / CHANGE LIST](../../docs/prompt-patterns.md) — use this pattern to structure the rewrite instruction before invoking the skill.
- [prompt-patterns.md §22 — The Closeout Trio](../../docs/prompt-patterns.md) — the summary format step 6 produces.
- [skills/verification-before-completion/](../verification-before-completion/) — the code-side equivalent of the Closeout Trio.
- [skills/handoff/](../handoff/) — session-end summary (different scope: session, not deliverable).
