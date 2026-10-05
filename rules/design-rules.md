# Design Rules
<!-- @-imported by CLAUDE.md. In backup.sh allowlist. -->

## Design source of truth (auto-use)
270 real brand design systems at `~/Repos/design-ai/design-md/<brand>/DESIGN.md`, indexed in `~/Repos/design-ai/BRANDS.txt` (repo root, one level above design-md).
On any non-trivial UI, frontend or landing-page task: grep the index, read the one file that matches the named brand or the closest fit, and say which you used. Treat it as the source of truth for colour, type, spacing and components, then pair it with `design-taste-frontend` for the craft (it already merges impeccable, so do not load both). Never invent a system when a fitting reference exists, and never read all 270.

## Reference libraries (when no DESIGN.md fits)
- Mobbin: screenshots of real shipped screens by flow (onboarding, paywall, empty state). Answers "what does a good version of THIS screen look like", which the brand library cannot. Free tier is limited, say so rather than promising a search.
- Fontshare: free typefaces outside the overused Google set, for when a build needs a voice and the chosen system does not license its own.
- motion.dev: worked examples for hover, drag and layout transitions. Reach for it when a build needs motion, rather than hand-rolling keyframes.

## Prompting /design
Every `/design` prompt names five things: how many directions you want, wireframe or polished, ONE bounded surface by name (a settings panel, not "the dashboard"), which existing components must appear, and either a named aesthetic or an explicit "structure only, ignore styling". The last is the one you skip and the one that matters: silence gets you the generic AI house style. Then judge the set by whether the options disagree about hierarchy or only about colour. Only about colour means the prompt was too narrow.

## UI QA
- Assert the active state before judging a themed or stateful UI. Log the real theme, variant or flag and confirm it matches the design you are comparing against. A verdict rendered under the wrong theme is a false negative that has burned whole sessions. ENFORCED: ui-state-gate.sh blocks the first style edit of a visual-QA session until a real query has returned the live theme. Pair `visual-verdict` (judge images) with `demo-qa` (drive and root-cause).
- Never self-certify a UI fix from your own screenshots. Find the cause in source, then have the user confirm in his browser.
- Theme parity is MEASURED, not eyeballed: `scripts/theme-parity.mjs <url>` diffs computed styles across both themes and names the element and property. Non-colour drift is the bug, identical colour means the element ignored the swap, and a page that does not respond aborts instead of returning a tidy list. `--emit-js` gives the same capture to paste into the Chrome MCP for a page behind a login.

## Component and docs MCPs
- Live everywhere: `shadcn` (pull real components, do not hand-roll primitives) and `context7` (current library docs before coding against an SDK).
- Not installed, do not offer them: `magic` (needs a 21st.dev key nobody has) and `reactbits` (no official server, only an unmaintained third-party one).
