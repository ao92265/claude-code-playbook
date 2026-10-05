---
name: design-system-diagrams
description: Make a diagram or explainer slide that has to look designed, as a 16:9 HTML file plus a PNG, styled with a real brand's colour, type and spacing tokens. Use for a deck, a talk, a training session, a one-pager or a doc header. Triggers: "/design-system-diagrams", "slide for my deck", "diagram for the talk", "explainer graphic", "concept slide", "before and after slide", "run sheet graphic", "visualise this process", "make this look designed", "make it deck ready". Do NOT use for charts of numeric data, UI mockups of real product screens, sketch style output (hand-drawn-diagrams), or an engineering architecture diagram (archify).
metadata:
  user-invocable: true
  slash-command: /design-system-diagrams
  proactive: false
---

# Design System Diagrams

Explainer diagrams that look like a designer made them, because the colour, type and spacing
come from a real design system instead of from defaults.

The output is a **self-contained HTML file at 1600x900** — no build step, no external fonts,
no scripts. It drops straight into a slide, a doc, or a browser.

## Why diagrams come out bog-standard

Four equal rounded rectangles in a row, one arrow between each, a title above. It is not
*wrong*, it just carries no thought. Every default the tool offers has been accepted.

This skill exists to refuse those defaults. Read `references/craft.md` before you draw
anything — it is the difference between output people use and output people politely ignore.

## Process

### 1. Pick the design system

The look is a decision, not a default. In order of preference:

1. **User named a brand or vibe** — resolve it against the local library:
   `grep -i "<brand>" ~/Repos/design-ai/BRANDS.txt`, then read
   `~/Repos/design-ai/design-md/<brand>/DESIGN.md`.
2. **User named their own theme or an existing file** — extract tokens from that file
   (see `references/tokens.md`, "Extracting from an existing artefact").
3. **Nothing named** — pick the closest fit for the audience and **say which you used**.
   Warm and approachable for non-technical audiences; sharp and high-contrast for technical.
4. **No library on this machine** — use a built-in token set from `references/tokens.md`.
   The skill is fully portable; the library is an upgrade, not a dependency.

Read exactly one DESIGN.md. Never read the whole library.

### 2. Pick one archetype

Read `references/archetypes.md` and choose **one**. One diagram answers one question.
If the content wants two archetypes, that is two diagrams.

### 3. Convert the design system to tokens

Read `references/tokens.md`. Produce a `:root` block of CSS custom properties — ink, surface,
accent, muted, border, plus a type scale and a spacing scale. Everything downstream references
those variables. No raw hex values below the `:root` block.

### 4. Build

Copy `assets/base.html` and fill the canvas. Rules that matter most:

- **Text is HTML.** Never render a label as part of an image — it must stay crisp and selectable.
- **Connectors and shapes are inline SVG or CSS.** No image files, no icon fonts, no CDN.
- **System font stack only**, matched to the design system's character. No web font fetches.
- **1–5 words per label.** If a label needs a sentence, it belongs in the caption row.
- Apply the whole of `references/craft.md`, not the easy half.

When the subject has a metaphor worth showing, or the audience is non-technical, add a
hand-drawn vector illustration — read `references/illustration.md` first. Default to
including one; skip it only when the canvas is already dense or the only candidate is a
cliché.

### 5. Render and check

```bash
open -a "Google Chrome" "/absolute/path/to/diagram.html"
```

Screenshot it, then check against the acceptance list in `references/craft.md`.
Fix and re-render until it passes. Expect two or three passes — the first draft of a
diagram is never the one you ship.

### 6. Hand over

Deliver the HTML path and the PNG. Then **ask the person to look at it in their own browser
before anyone calls it finished.** Do not certify your own screenshot — colour, font
rendering and scaling all differ on the real machine.

## Output locations

- Default: a scratch directory, one folder per diagram.
- Write into the user's project only when they name a path or ask for it.
- Filenames describe the content: `run-sheet.html`, not `diagram-1.html`.

## Common issues

**Text overflows its box.** The label is too long. Shorten to 1–5 words or move it to a
caption. Do not shrink the font below the type scale — that breaks the hierarchy.

**It looks flat and grey.** Accent is doing nothing. Pick the one element that carries the
message and give it the accent; return everything else to ink and muted.

**It looks noisy.** Count the colours. More than one accent plus neutrals means the diagram
is fighting itself. Also check for gratuitous shadows and borders on every element.

**Screenshot is blurry or clipped.** The browser window is smaller than 1600x900, or page
zoom is not 100%. Resize the window and reset zoom before shooting.

**Brand not in the library.** `BRANDS.txt` holds 238 systems and none of them is your
employer. Extract tokens from an existing artefact instead, or use a built-in set — both
in `references/tokens.md`.

**Fonts render differently on the reviewer's machine.** Expected, and exactly why step 6
exists. Keep to the system stack so the fallback is graceful.
