# Plan style: chaptered approval-grade PLAN + styled HTML artifact

Use when the user wants a **delivery plan a leadership reader can approve or decline
from in one read**, not a PRD. The PRD (`prd.json`) stays the machine artifact; the PLAN
is the human one, written as a second pass on top of it.

Two scripts in this directory build it: `inject.py` swaps prose passages for diagrams and
tables, `assemble.py` wraps the converted body in the styled shell. Both are driven by a
`plan-config.json` you write per project (see `plan-config.example.json` for the shape and
every required key). The scripts carry no project content of their own.

Both fail loudly when a content anchor drifts. Keep that property. A plan gets edited
between builds, and a silently skipped diagram is worse than a failed build: the reader
gets a paragraph where a picture should be and nobody notices.

## Document format (the writer agent's contract)

Three acts, told as a story. Chapter numbering continuous.

1. **Start here · The five-minute version.** TLDR section before chapter 1: a stat-tile
   row (5 to 6 headline numbers) then ~7 bold-lead paragraphs: the decision on the
   table, why bother, what the money buys in order, the tripwires/gates, what could
   kill it, what done looks like, the one unresolved thing. Every number must appear
   somewhere in the body chapters; the TLDR never introduces a fact.
2. **Act 1 · The story** (scene-setting): why we're here + who's who table; the world we
   operate in; the money; how we got here (lineage diagram); what we're building
   (vocab table + architecture diagram); the ground we stand on; the rules of the game
   (the hard gates).
3. **Act 2 · The plan**: the shape of the whole (gantt); core flows (request-flow
   diagram); week 0; then one chapter per workstream with numbered batches and
   cut-ready issues.
4. **Act 3 · Keeping it honest**: asks on other people; open questions that block work
   (with owners); risks + the ordered cut line (first-cut first, then "never cut");
   what done means, including the designed retreat position; sources block at the end.

Authoring rules (hard, enforced by assemble.py):
- **No em or en dashes anywhere.** The build dies if one survives.
- **One HTML-comment anchor per chapter** (`<!-- == CHAPTER N == -->`) plus
  `<a id="chN"></a>` before each heading; chapter-scoped edits rely on them.
- Chapter headings exactly `## Chapter N · Title` (assemble counts them).
- A `## Contents` section with `**Group**` + link lists: it becomes the sidebar nav
  verbatim, and ends with an *italic* provenance note that becomes the nav footer.
- Gates as a 5-column table (Gate / What passes / What fails / Failure action /
  Kill call): assemble turns it into gate cards.
- Week-at-a-glance table starts `| **Week** |`: assemble gives it the sticky first
  column treatment.
- Label every number as doc-native or plan-authored (requires ratification) when the
  plan is derived from someone else's strategy document.
- Severability paragraph up front: which chapter subsets read as approval-grade /
  due-diligence / opinion.

## Pipeline

```
python3 inject.py plan-config.json <plan>.md <work>/enhanced.md
npx marked --gfm -i <work>/enhanced.md -o <work>/body.html
python3 assemble.py plan-config.json <work>
# publish the fragment via the Artifact tool; pass url= to keep an existing artifact URL
# send the share copy as the file; it needs nothing but a browser
```

Per project you write `plan-config.json`: the inject replacements (anchor plus diagram
body), the gantt rows and gates, the stat tiles, the hero band (`hero.meta` and a one-line
`hero.summary`), the figure labels, the artwork directory,
and the title and brand strings. Nothing else needs touching.

Requires `npx marked`, `@mermaid-js/mermaid-cli` (`mmdc`) and a local
`chrome-headless-shell` for the figure baking step. Check these are installed before
promising the styled output; the markdown PLAN itself is useful without them.

## Visual system (Stripe-derived, both themes)

- Tokens defined once for light, once for dark, applied via `:root`,
  `@media (prefers-color-scheme: dark)`, AND `:root[data-theme=...]` overrides so the
  artifact viewer's theme toggle wins in both directions.
- Layout: sticky sidebar nav (272px) + main column capped at one content width
  (1180px), clamped padding. **One width for everything**: prose, tables, gantt and
  diagram cards all span the same column, no per-element `max-width` caps. The mixed
  narrow-prose / full-width-table look was tried and rejected: it makes a document that
  should read as one artifact feel like two pasted together. Wide furniture keeps
  `overflow-x:auto` only as a narrow-window fallback; the page body never scrolls sideways.
- Components: stat tiles, workstream colour pills, gate cards with pass/fail/action
  cells and a kill-call footer, sticky-first-column week table, hand-built CSS gantt
  (batch bars, gate diamonds, phase bands, sticky labels), scrollspy sidebar, and a
  fixed round theme-flip button (top right) that toggles `data-theme` on the root.
- Diagrams are authored as plain mermaid fences, then **baked to inline SVG by
  assemble.py** so the page renders with nothing but a browser (see "Baked figures"
  below). The card around them uses page tokens, same as every other card.
- Artwork: flat editorial illustrations (hero above the TLDR, one divider above each
  act break, one at the done chapter), generated from palette-locked prompts (strict hex
  list, "no text, no people", wide banners, "same style as previous image" for set
  consistency). Store as quality-82 JPEGs at roughly 60 to 140KB each (generated PNGs
  carry grain and run about 1MB; resize to 1800px then convert). assemble.py embeds them
  as base64 data URIs, because the artifact CSP blocks external images. Frame them in
  token-bordered cards so fixed-light art reads as intentional figures in dark mode.

## Baked figures (why, and how the colours work)

- **A plan that gets emailed cannot depend on the artifact runtime.** On claude.ai the
  runtime hides each `pre.mermaid` and mounts its own rendered `div.mermaid-diagram`;
  the same file opened from Downloads has no mermaid engine, so the reader sees raw
  `flowchart LR` source. This is not hypothetical: it is how a plan once reached a
  colleague's inbox with three blocks of code where the diagrams should have been.
- assemble.py step 1 renders each fence with `mmdc` (`@mermaid-js/mermaid-cli`, plus
  a local `chrome-headless-shell`; about 1s per diagram, no network) and inlines the
  SVG in a `figure.fig` panel (tinted `--fig` token), with the figure label as its caption. Below
  620px wide the canvas scrolls sideways inside the panel rather than shrinking.
- Theme family: `assemble.py` takes every family's tokens and the default (`data-family` on
  `<html>`, Grid today) from `../prd-template.html`, so the plan, PRD and bundle switch together.
  Figures bake to the family's diagram tokens (`--dg-*`, `--fig`). project-f stays one value away.
- Colours come from a **sentinel palette**: mermaid renders with unmistakable hexes
  (`#f01f01`, `#a11101`, ...) pinned through `themeVariables`, and assemble.py swaps
  each for a page token (`var(--panel)`, `var(--line2)`, `var(--head)`,
  `var(--muted)`, `var(--bg)`, `var(--line)`, `var(--card)`). One SVG then follows
  light, dark and the flip button with no JavaScript. Pin every colour variable
  explicitly so mermaid derives nothing: the build dies listing any colour that
  survives, and the fix is always one more variable in FIG_CFG.
- Per-diagram housekeeping in the same step: rename mermaid's `my-svg` id per figure
  (three copies in one document otherwise collide on marker ids), force
  `.edgeLabel rect` to full opacity, swap the inline `max-width` for
  `width:100%;height:auto`, and add an `aria-label` from the config's figure labels.
- Two outputs, because the artifact wants a body fragment while an emailed file wants
  a document: `<slug>-plan.html` (fragment, what gets published) and
  `<slug>-plan-share.html` (doctype, charset, viewport, head). Without the doctype
  Chrome renders the file in quirks mode; without the viewport tag phones shrink it.
- The artifact page follows the viewer's device theme and exposes no obvious switch;
  ship the in-page theme-flip button (see assemble.py JS). Setting `data-theme` on
  the root triggers the token overrides, and the baked figures follow them.
- Republish with the same `url` param to keep the artifact link; keep the favicon
  emoji stable across republishes.
- `npx marked --gfm` passes raw HTML and HTML comments through untouched; the
  transforms depend on that.
