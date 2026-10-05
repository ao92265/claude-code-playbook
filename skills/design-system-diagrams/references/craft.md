# Craft

The rules that separate a diagram people use from a diagram people politely ignore.
Apply all of them. The tempting half is the half that gets skipped.

## The slide test

Stand three metres back. You should be able to read the one-sentence point of the diagram
before you can read any of its labels. If the whole thing has to be read to be understood,
it is a document, not a diagram.

## 1. One thing dominates

A row of five identically-sized boxes tells the eye that all five matter equally. They never
do. Decide what the viewer should see first, then make it bigger, heavier, or the only thing
carrying the accent colour.

Hierarchy comes from **size, weight and colour** — in that order. Not from borders.

## 2. Type carries the structure

Use at least three distinct sizes with real gaps between them:

- **Title** — the point of the diagram, stated as a claim, not a topic. "Most people skip
  context" beats "The prompt pattern".
- **Label** — inside or beside elements. 1–5 words.
- **Caption** — supporting detail, one size down and in muted ink.

A 2px difference is not a size difference. Use a ratio around 1.25–1.4 between steps.
Weight does more work than size at small sizes: 600 against 400 reads instantly.

Numbers that matter (durations, counts, percentages) get their own treatment — larger,
tabular figures, `font-variant-numeric: tabular-nums`.

## 3. Space is the design

Every gap comes from one scale — 4, 8, 12, 16, 24, 32, 48, 64, 96. Never an arbitrary 13px.

Related things sit close. Unrelated things sit far apart. That contrast does more grouping
work than any border or box will. When something looks wrong and you cannot say why, it is
almost always spacing.

Generous outer margin. A diagram that touches its own edges looks unfinished.

## 4. Colour with restraint

- **Ink** for text and structure.
- **Muted** for secondary text and quiet lines.
- **Surface** for the background and any raised panel.
- **One accent**, doing exactly one job — marking the element that carries the message.

If a second accent appears, it must encode something real (a genuine before/after, a true
warning). Colour per box, rainbow-style, is decoration and reads as clip art.

Body text needs a contrast ratio of at least 4.5:1 against its background; large text 3:1.
Check it rather than assuming.

## 5. Kill the defaults

Named and banned, because these are what "bog-standard" actually looks like:

- The default arrow — a thin grey line with a filled triangle. Give connectors intent:
  weight that matches their importance, ends that stop cleanly at the shape.
- Uniform border-radius on everything. Pick a radius that suits the system and use it
  consistently, or use none.
- A 1px grey border around every element. Most boxes do not need a border at all — spacing
  and background already separate them.
- Drop shadows with no elevation logic.
- Centre-aligned body text. Centre titles if the design system does; left-align anything
  longer than a few words.
- Icons chosen because a box looked empty.

## 6. Every stroke carries information

If you cannot say what a line, box, shadow or colour *means*, delete it. An empty container
is worse than no container. Decoration is the tell that nobody thought about the content.

## 7. Alignment is optical, not arithmetic

Elements sit on a grid. But when mathematical centring looks off — text beside a circle,
a label under a wide shape — trust the eye and nudge. Round shapes generally need slightly
more space than square ones to look equally spaced.

## 8. The title is a claim

The single highest-leverage improvement to most diagrams. "Prompting" is a label.
"Four parts, in order, or you get mush" is a diagram people remember.

## Acceptance list

Check every line before handing over. A "no" means another pass, not a caveat.

- [ ] The point is readable from three metres.
- [ ] One element clearly dominates.
- [ ] Three or more distinct type sizes, with real gaps.
- [ ] Every gap comes from the spacing scale.
- [ ] Exactly one accent colour, doing one job.
- [ ] Text contrast at least 4.5:1.
- [ ] No element present without a meaning.
- [ ] Every label is 1–5 words.
- [ ] Nothing clipped, nothing overflowing, nothing touching the canvas edge.
- [ ] The title states a claim, not a topic.
- [ ] It still reads correctly at 50% scale (slide thumbnail test).
