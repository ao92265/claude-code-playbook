# Tokens

Every diagram starts with a `:root` block. Below that block, no raw hex values appear
anywhere in the file.

## The shape of it

```css
:root {
  /* colour */
  --surface:      /* canvas background */
  --surface-alt:  /* raised panel, subtle step from surface */
  --ink:          /* primary text and structure */
  --ink-muted:    /* captions, secondary labels */
  --border:       /* quiet lines; often just ink at low alpha */
  --accent:       /* ONE accent, one job */
  --accent-ink:   /* text colour that sits on the accent */

  /* type */
  --font: /* system stack, matched to the design system's character */
  --size-title: 56px;
  --size-lead:  32px;
  --size-label: 22px;
  --size-caption: 17px;

  /* space */
  --s1: 4px;  --s2: 8px;  --s3: 12px; --s4: 16px;
  --s5: 24px; --s6: 32px; --s7: 48px; --s8: 64px; --s9: 96px;

  --radius: /* 0, or one value used consistently */
}
```

Adjust the type sizes to the design system's own scale and ratio — these are a starting
point for a 1600x900 canvas, not a standard.

## Font stacks

No web font fetches, ever. A self-contained file that reaches out for a font is not
self-contained. Match the *character* of the design system with a system stack:

| Character | Stack |
|---|---|
| Neutral / corporate | `"Segoe UI", system-ui, -apple-system, "Helvetica Neue", sans-serif` |
| Modern / geometric | `"Avenir Next", "Futura", system-ui, sans-serif` |
| Editorial / warm | `"Charter", "Iowan Old Style", Georgia, serif` |
| Technical / precise | `ui-monospace, "SF Mono", Menlo, monospace` |

When the design system names a font the machine will not have (Inter, Söhne, Circular,
GT America), put it first and let the stack fall back. It costs nothing and helps on
machines that do have it.

## Reading a DESIGN.md

The files in `~/Repos/design-ai/design-md/<brand>/DESIGN.md` follow a stable structure.
Take from these sections and ignore the rest:

- **2. Color Palette & Roles** — the core foundation, brand accent, and surface/border
  scales. Map their roles onto the variables above; do not import their whole palette.
- **3. Typography Rules** — the font stack, type scale ratio, and which weights the system
  actually uses.
- **5. Layout Principles** — the spacing scale and the whitespace philosophy. If the system
  is generous, be generous.
- **1. Visual Theme & Atmosphere** — read it for character. It tells you whether the design
  wants restraint or confidence.

Take **one** accent from the brand palette even when the brand has five. The design system
supplies the vocabulary; the diagram still needs an editor.

## Extracting from an existing artefact

When the user points at their own deck, site or template:

```bash
grep -oE "#[0-9a-fA-F]{6}" <file> | sort | uniq -c | sort -rn | head -12
grep -oiE "font-family:[^;]{0,80}" <file> | sort -u
```

Frequency ordering usually reveals the roles: the most common dark value is ink or surface,
the outlier saturated value is the accent. Confirm by looking at the artefact rather than
trusting the counts.

## Built-in sets

Use these when no library is present and no artefact is available. Each is checked for
contrast at 4.5:1 on body text.

### Ink on paper — safest default, works in any deck

```css
--surface:#ffffff; --surface-alt:#f5f5f4; --ink:#1c1917; --ink-muted:#78716c;
--border:#e7e5e4; --accent:#1c1917; --accent-ink:#ffffff;
```
Accent is the ink itself — emphasis comes from a filled block rather than a hue.
Unkillable, and prints.

### Deep navy — for dark decks

```css
--surface:#0a1620; --surface-alt:#123240; --ink:#eaf2f8; --ink-muted:#8aa0b2;
--border:#1c2e3c; --accent:#3fd0c9; --accent-ink:#06101a;
```

### Warm neutral — for non-technical, approachable audiences

```css
--surface:#fdfcfb; --surface-alt:#f4f0ea; --ink:#2b2622; --ink-muted:#7a7069;
--border:#e5ded4; --accent:#b45309; --accent-ink:#ffffff;
```

## Dark and light

A diagram lives in one deck with one background. Pick the mode that matches the deck and
commit to it. Do not build a theme switcher — it doubles the work and halves the care in
each version.
