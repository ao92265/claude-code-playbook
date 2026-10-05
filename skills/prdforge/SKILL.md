---
name: prdforge
description: >
  Self-interviewing planner that produces a deep plan without interrogating you.
  Fans out multi-agent "ultracode" interviewer personas that GENERATE and ANSWER
  the questions a senior planner would ask, then renders a self-contained HTML PRD
  plus a paste-ready implementation prompt. Local, no-git, no-cloud alternative to
  the native /ultraplan. Use when the user wants a deep plan, PRD, spec, or "really
  good prompt" for a non-trivial feature, or says "prdforge", "ultraprd", "selfplan",
  "deepplan", "self-interview", "make a PRD", "plan this deeply", "write me a spec",
  or "forge a prd". Flag --handoff (also "sonnet handoff", "cheap model plan")
  additionally emits an execution plan a cheaper model can run task-by-task without you.
  Runs fully autonomously: states assumptions and open questions
  inside the PRD instead of interrupting.
  Do NOT use for one-line fixes, lookups, trivial edits, or when the user just wants
  code written immediately with no plan.
metadata:
  user-invocable: true
  slash-command: /prdforge
  proactive: false
effort: high
---

# prdforge

Turns a vague idea into a deep PRD by **self-interviewing**: instead of asking the user
ten questions one at a time (native `plan` / `deep-interview`), it fans out interviewer
agents that ask *and answer* the questions themselves, flag what they can't confidently
answer as Open Questions, and emit a styled **HTML PRD** + a **paste-ready prompt**.

This is the local replacement for the native `/ultraplan`, which requires a cloud session
and a git repo. prdforge needs neither.

## When to invoke

- The user wants a deep plan / PRD / spec for a non-trivial feature, refactor, or system.
- The request reads like a one-liner ("add billing", "make it multi-tenant") that needs unpacking before code.
- Triggers: "prdforge", "ultraprd", "selfplan", "deepplan", "make a PRD", "plan this deeply", "write me a spec".

Skip for: one-line fixes, lookups, trivial edits, or "just write the code".

## How to run (exact steps)

1. **Parse the request.** Strip any flags from the user's text. Mode is always `deep`
   (see Decision rules); strip `--quick` / `--balanced` if given. Recognize the `--handoff` flag
   (extra artifact: cheap-model execution plan, step 7), `--inputs <file> [<file>...]`
   (documents whose facts, requirement IDs and demand evidence feed the PRD, for example a
   requirements register or an earlier analysis), and an optional output path.
   Map the mode flag to `mode` for `args` below.
2. **Compute `slug`** from the idea: kebab-case, lowercased, max ~6 words (e.g.
   "rate limiting for the API" → `rate-limiting-for-the-api`). You (the main loop) MUST
   compute this; the Workflow script cannot (no `Date.now()`/`Math.random()` inside scripts).
   Also compute `date` (today, e.g. `24 September 2026`): the script cannot call `Date`.
3. **Resolve `outDir`** = `plans` relative to cwd, unless the user named a directory.
4. **Detect `brownfield`** = does cwd look like a code project? (presence of `package.json`,
   `.git`, `src/`, `Cargo.toml`, `go.mod`, `pyproject.toml`, etc.) If unsure, treat as brownfield.
5. **Run the workflow**: this is the ultracode opt-in:

   **Requires `mmdc` for the PRD, not only for the plan** (`npm i -g @mermaid-js/mermaid-cli`).
   Every PRD diagram is baked to SVG at render time; without `mmdc` on PATH the render exits 1
   (it will not ship raw mermaid text) and the bundle refuses to build.

   **Paths must be absolute.** Expand `~` to your home directory before calling: the
   `Workflow` tool's `scriptPath` and the workflow's inner `Read(templatePath)` do NOT
   expand `~`: a literal `~` fails to resolve, and `templatePath` then silently degrades
   to the generated-from-contract fallback (un-themed PRD). Pass e.g.
   `/Users/<you>/.claude/skills/prdforge/assets/...`.

   ```
   Workflow({
     scriptPath: "<HOME>/.claude/skills/prdforge/assets/self-interview.workflow.js",
     args: {
       idea: "the cleaned request",
       brownfield: true | false,
       mode: "deep",
       outDir: "plans",
       slug: "computed-slug",
       templatePath: "<HOME>/.claude/skills/prdforge/assets/prd-template.html",
       rendererPath: "<HOME>/.claude/skills/prdforge/assets/render_prd.py",
       lintPath: "<HOME>/.claude/skills/prd-review/scripts/score.py",
       inputs: ["/absolute/path/to/input.md"],   // [] when none
       date: "24 September 2026"
     }
   })
   ```
   Pass `args` as a real object, not a JSON string (the script self-parses either, but
   an object is correct).

6. **If `verified` is false, STOP.** The render failed a check (diagrams, dashes, external
   references, anything) even after the fix pass. Do not run `bundle.py` and do not publish
   anything. Report the render's issues and the file paths, and say what has to change.
   **On return with `verified` true**, print a tight summary: one line on what was planned, the **readiness score**
   (`readiness.score`/100 + label), the **linter score** (`lintScore`/100 from prd-review, or
   "not run"), the four artifact paths (`<slug>-prd.html`, `<slug>-prd.md`, `<slug>-prompt.md`,
   `<slug>-prd.json`) plus the bundle link (below), and the PRD's **Open Questions** (`Q-n`, question, confidence, owner:
   the low-confidence defaults prdforge assumed and wants confirmed). Then **offer** (do not
   force) either to hand the paste-ready prompt straight to an implementation agent (whatever
   the user has: a general-purpose `Agent` call is the stock option), or to answer the open
   questions so prdforge can tighten the prompt first.
   Never auto-implement and never auto-ask; prdforge stops at the PRD.
   **Bundle last, as the one link:** after steps 7 and 8 have written their files, run
   `python3 <HOME>/.claude/skills/prdforge/assets/bundle.py --out-dir <outDir> --slug <slug>`
   (must exit 0) and publish `<slug>-bundle.html` as the single Artifact link in the summary.
   `bundle.py` re-runs the diagrams gate on `<slug>-prd.json` and the PRD page itself and
   exits 1 without writing if it fails; a non-zero exit means stop, never publish an older file.
7. **Handoff render** (only if `--handoff`): spawn ONE writer agent (`model=sonnet`) that
   reads `outDir/<slug>-prd.json` and writes `outDir/<slug>-handoff.md` in the HANDOFF PLAN
   format defined in `references/prd-contract.md`. Rules for the agent:
   - TASKS come from the FR IDs: each task names the FR it serves and its done-check is that
     FR's Given/When/Then scenarios. Milestones come from the PRD's `releases`.
   - Every TASK sized for one Sonnet session: names the files it touches + a done-check
     (command or observable) a model can verify alone.
   - SUCCESS items must be mechanically checkable (command + expected output), never "works well".
   - Open Questions from the PRD land in HANDOFF > Gotchas as "ASK USER FIRST" items.
   Add the handoff path to the step-6 summary.
8. **Plan-style render: ON BY DEFAULT** (the user's rule, 24 Sep 2026: he wants the diagrams and
   artwork every run; skip only on `--no-plan`). After the PRD, spawn ONE writer agent (inherit
   top tier: this is judgment writing, not mechanical) that reads `outDir/<slug>-prd.json`
   plus the source material and writes `outDir/<slug>-PLAN.md` in the chaptered three-act
   format defined in `assets/plan-style/STYLE.md`, then build and style it per that file's
   pipeline (write a `plan-config.json`, run inject and assemble), then rebuild the bundle
   (step 6) so the plan appears as its tab; publish the bundle, not the plan on its own.
   This is the approval-grade, leadership-readable format; the PRD stays the machine artifact.
   The PLAN is not a specification: it must cite the PRD's FR/G/D/Q IDs rather than restate
   capabilities at module level, and its release chapter must carry the PRD's sizes.
   The styled HTML build needs `npx marked`, `mmdc` and a local `chrome-headless-shell`;
   if they are missing, deliver the markdown PLAN and say the styling step was skipped.
   Artwork (hero plus act dividers) comes from the `imagegen` skill as 16:9 photographs of
   real objects (not abstract shapes), no text, no faces; resize to 1800px quality-82 JPEGs
   in `outDir/art/`. Add the share-file path to the step-6 summary.

## Decision rules

- **Mode: always full (`deep`).** the user's rule (24 Sep 2026): every run is 6 personas, 2 rounds,
  critic and revise, about 18 agents. `--quick` / `--balanced` are ignored and logged. Measured
  24 Sep 2026: 1.17M subagent tokens and 17 min on a one-flag feature, so say the cost before a run.
- **Critic pass** → after synthesis, `critic` adversarially
  reviews the draft PRD (fabrication, scope creep, unverifiable criteria, missing risks); a
  reviser applies any med/high findings before render. Separate writer/reviewer lanes.
- **Greenfield** (no codebase) → the Scout phase is skipped; personas reason from the idea alone.
- **Brownfield** → a Scout (Explore) agent gathers repo facts AND up to ~60 behaviour rules
  (`<AREA>-n`, Preserve/Decide, `file:line`) so requirements trace below module level. If the idea
  targets a specific path, name it in the idea text so Scout focuses there.
- **Input documents** (`--inputs`) → a second Scout reads them; requirement IDs, demand evidence and
  figures come through tagged `[Doc: name]`, and the PRD states its prioritisation rule from them.
- **Scope discipline** → the Skeptic persona exists to cut over-built scope; honor its "simplest
  version" output in Non-Goals.

## Output

Four files in `outDir` (five with `--handoff`), all built by `assets/render_prd.py` from the JSON:
- `<slug>-prd.html`: self-contained PRD in the **project-f visual system** (same tokens and furniture
  as `assets/plan-style/`): sidebar nav with scrollspy, a hero with title, one-line summary and
  stat cards (readiness meter in the first), a "five-minute version" panel, 3 or 4 required
  captioned diagrams (system, main flow, delivery; the render fails without them), chapters grouped into acts, requirement cards with Given/When/Then,
  gate cards, light and dark themes plus a flip button, copy-prompt, and an Open-Questions
  checklist whose ticks persist in the browser (with an answered count). Every ID mention (FR, G,
  D, Q, R, legacy rules) links to where it is defined and highlights it; requirements have a
  priority mix bar plus MoSCoW filter and search; risks get a likelihood by impact heatmap; stat
  tiles jump to their chapter; a reading bar tracks progress. No sideways scroll at phone width. Opens offline, zero external requests. It is a
  whole document, so it can be emailed as is or published as an Artifact.
- `<slug>-prd.md`: the same PRD as markdown, the input the prd-review linter scores.
- `<slug>-prompt.md`: the implementation prompt in Context / Objective / Boundaries / Validation form.
- `<slug>-prd.json`: the final PRD model, including the lint result, for downstream tooling.
- `<slug>-handoff.md`: (only with `--handoff`) cheap-model execution plan.
- `<slug>-PLAN.md` plus `<slug>-plan.html` / `<slug>-plan-share.html`: (default, skip with
  `--no-plan`) the chaptered delivery plan with baked diagrams and generated artwork (step 8).
- `<slug>-bundle.html`: every output above in one offline page behind a sticky tab bar (PRD,
  Plan, Prompt, Handoff; a tab is skipped when its file is missing), one theme toggle for all,
  tab in the URL hash (`#plan`). Built by `assets/bundle.py`; this is the link to publish.

Section contract, the `readiness`/`openQuestions` shapes, and the prompt format are defined in
`references/prd-contract.md` (reuses the `spec` skill's framing). Consult it if the PRD model needs adjusting.

## Common Issues

- **`Workflow` tool not available or not opted in** (most likely first failure on a fresh
  install) → run the same phases by hand with the `Agent` tool: spawn the personas as
  parallel `Agent(subagent_type="general-purpose")` calls, synthesize their answers inline,
  send the draft to one more `general-purpose` agent for an adversarial critique pass, then
  write the PRD JSON to `<outDir>/<slug>-prd.json` and run `render_prd.py` on it yourself. Same artifacts, no deterministic
  orchestration and no retry/resume.
- **`Write` doesn't create parent dirs** → the Render agent runs `mkdir -p <outDir>` before writing.
- **Render failed** → run `python3 <rendererPath> --json <outDir>/<slug>-prd.json --template <templatePath> --lint <lintPath>`
  by hand; it prints what failed. If `rendererPath` was not passed, the render agent hand-builds
  the files from `references/prd-contract.md` and no lint score is produced.
- **Linter score low** → Verify already ran one fix pass. Open `<slug>-prd.md` and run
  `/prd-review` on it for the semantic review the linter cannot do.
- **Slug or timestamp logic** → never inside the Workflow script (`Date.now()`/`Math.random()` throw).
  Compute `slug` in the main loop and pass via `args`.
- **Cost** → every run is full depth (about 1.2M subagent tokens). There is no cheap mode by design.
- **Interactive HTML broken / not themed** → the template's inline `<script>` and `<style>` must
  survive; `render_prd.py` exits 1 if either is missing. Edit the shell, never the generated file.

## References

- `references/prd-contract.md`: PRD section definitions + implementation-spec format.
- `assets/self-interview.workflow.js`: the ultracode orchestration script.
- `assets/prd-template.html`: the HTML shell (CSS + JS); the body is generated.
- `assets/render_prd.py`: deterministic JSON to HTML + markdown + prompt renderer, self-check, lint.
- `assets/bundle.py`: deterministic tabbed bundle of all outputs for one slug (iframe per document).
- `assets/check_contrast.py`: WCAG AA gate for the theme families; run it on any built page (`--all` for every family).
- `assets/plan-style/STYLE.md`: the chaptered approval-grade PLAN format + styled
  HTML shell (Stripe-derived, sidebar nav, gate cards, CSS gantt, five-minute TLDR).
  `inject.py` and `assemble.py` build it from a per-project `plan-config.json`; see
  `plan-config.example.json` for the shape. Used by step 8 (default; `--no-plan` skips it).
