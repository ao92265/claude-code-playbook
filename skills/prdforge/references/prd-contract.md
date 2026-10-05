# PRD contract

The section definitions the Synthesize agent fills (`PRD_SCHEMA` in
`assets/self-interview.workflow.js`) and the Render agent lays out
(`assets/prd-template.html`). Loaded on demand to keep `SKILL.md` lean.

## Section definitions (v3)

v3 answers the Project project-e review (24 Sep 2026): an earlier prdforge output was "not a specification.
No requirement IDs, no acceptance criteria, no non-functional targets." Every section below exists so
that a chapter can be handed to an agent and come back as a testable ticket.

| Section | What belongs | What does NOT |
|---|---|---|
| **docControl** | version, status, owner (role or "Unassigned"), date, mode, inputs. | An invented owner name. |
| **title / summary** | Short name; 1 to 2 sentences on what and why. | Marketing, implementation detail. |
| **readiness** | `{ score, label, rationale }`. Score is computed, see below. | A vanity 100. |
| **contestable** | 2 to 4 judgements a reviewer should argue rather than inherit. | Restating open questions. |
| **problem / users** | The pain, with evidence tags; users with need and priority. | The solution. |
| **goals** | `G-n { goal, metric, baseline, baselineMeasured, target, measuredBy, source }`. Unmeasured baseline = provisional target + an open question. | Code shape. |
| **nonGoals** | `NG-n { text, rationale, returns }`. `returns` = when it comes back, or "Not planned". | Vague "maybe later". |
| **context** | Current state. Every claim and number carries a unit and an evidence tag: `[Code] file:line`, `[Doc: name]`, `[Demo]`, `[Assumption]`, `[Unknown]`. | Untagged figures, currency-less money. |
| **glossary / constraints** | Domain terms; `DA-n` cross-cutting data and authorisation constraints. Empty when the domain has none. | Filler entries. |
| **legacyRules** | Brownfield: `<AREA>-n { rule, fileLine, class: Preserve/Decide }`, capped at about 60 by Scout and said to be capped. Requirements cite them in `trace`. | Parity asserted at module level only. |
| **requirements.functional** | `FR-<AREA>-n { priority (MoSCoW), title, statement, acceptance[Given/When/Then], trace, source, singleSource }`. ONE capability each. Every priority has at least one scenario; Musts also a denied, empty or already-done case. | Bundled capabilities, technology names, unbounded words ("any module"). |
| **requirements.nonFunctional** | `NFR-n { requirement, target (number + unit + condition), measuredBy, baselineMeasured, source }`. | "Fast", "scalable". |
| **releases** | Ordered `{ name, contents, size (S/M/L + person-week range), sizeBasis, unblocks }`. | An unsized release (that becomes an open question). |
| **gates** | Deep mode only: `{ gate, passes, fails, failureAction, call }`. | Dates dressed up as gates. |
| **dependencyChains** | `{ chain, consequence }`: what decides build order. | |
| **prioritisationRule** | The explicit rule and its evidence, or "No demand evidence supplied". | Unstated taste. |
| **decisions** | `D-n { question, decision, why, tradeOff, status }`. Every disagreement between lenses lands here. | Conflicts resolved silently. |
| **assumptions** | `A-n { text, source }`: made with reasonable confidence; the user can veto. | Unresolved items (those are open questions). |
| **openQuestions** | `Q-n { question, confidence 0..1, why, owner (role), blocks [IDs], neededBy }`. | Rhetorical questions. |
| **risks** | `R-n { title, likelihood, impact, mitigation, owner }`. Mitigation becomes a test or gate where possible. | "It might break". |
| **testStrategy / definitionOfDone** | Requirement group, then the test layer that proves it; one-line definition of done. | |
| **verification** | Runnable checks with expected results. | "Make sure it works". |
| **implementationSpec** | The paste-ready prompt, below. | A second copy of the requirements. |
| **diagrams** (required) | 3 or 4 `{ kind, chapter, label, caption, mermaid }`. Required kinds: `system` in `context` (the parts and what flows between them), `flow` in `functional` (the main user flow or a sequence, citing FR IDs), `delivery` in `releases` (releases in order with gates and failure routes). Optional 4th: `risk` or `state` in `risks`. `label` is the accessible name, `caption` one or two plain sentences under the figure. Mermaid (flowchart, sequenceDiagram or stateDiagram-v2; flowchart node labels in double quotes, sequence and state labels plain; no styling) is baked to token-themed inline SVG when `mmdc` is installed; a hand-made `svg` is used as given after scripts and external references are stripped. The render FAILS on fewer than 3, a missing required kind, a missing caption, a diagram that does not render, or an unthemed colour. | Decoration, a diagram that restates a table, new scope, an unknown chapter anchor. |

## Rendering (deterministic, v3)

The LLM no longer fills an HTML template. The render agent writes `<slug>-prd.json` and runs
`assets/render_prd.py`, which builds `<slug>-prd.html` (the template shell plus a generated body),
`<slug>-prd.md` and `<slug>-prompt.md`, self-checks the HTML (no leftover tokens, no external
references, inline script and style intact), and runs the prd-review linter (`score.py`) on the
markdown. The score is shown in both documents and returned to the main loop. Under 85 triggers one
targeted fix pass and a re-render.

## Implementation-spec format (reused from the `spec` skill)

`implementationSpec` mirrors `~/.claude/skills/spec/SKILL.md` exactly : four parts, all required.
Rendered into the HTML "Implementation Prompt" section and written verbatim to `<slug>-prompt.md`.

- **context** : What exists right now: exact file paths, current behavior, relevant constraints. Name the files; no "the codebase".
- **objective** : What the change must *accomplish* (outcome), NOT what the code should look like.
- **boundaries** : What must NOT change: files off-limits, behaviors/interfaces/schemas frozen. Always include an explicit "do not modify outside X" line.
- **validation** : How to confirm it works: exact test/build command + expected result. New behavior requires new tests.

The `-prompt.md` file's literal shape:

```
Context: <files + current behavior + constraints>

Objective: <outcome to achieve : not code shape>

Boundaries: Do not modify <files>. Do not change <behavior/schema>.

Validation: Run <command>. <expected pass condition>. Add tests for <new behavior>.
```

## Confidence → Open Question rule

Each persona self-answer carries a `confidence` (0..1). Answers below ~0.6 become Open
Questions : this is prdforge's automated stand-in for `deep-interview`'s ambiguity gate:
instead of asking the user every question up front, it answers them all, then surfaces only
the ones it couldn't answer well. High-confidence answers become Assumptions the user can skim.

## Readiness score : deterministic (FROZEN)

`readiness.score` is **not** LLM-authored : the synthesize agent's number is overwritten by a
deterministic computation in `self-interview.workflow.js` (`computeReadiness`) so the same idea +
mode reproduces the same score. The frozen formula:

```
score  = round(100 * meanSelfAnswerConfidence)   // 0..1 mean of every persona qa[].confidence
score -= min(openQuestions.length * 5, 30)        // capped open-question penalty
score -= highRiskCount * 6                         // risks with impact high AND likelihood not low (v3; was severity high)
score  = clamp(score, 0, 100)
if (openQuestions > 0 || highRisks > 0) score = min(score, 89)   // never "build-ready green" with unknowns
if (mode === 'quick')                   score = min(score, 70)   // quick has limited coverage
label  = score>=70 ? 'Build-ready' : score>=40 ? 'Shaping' : 'Exploratory'
```

The LLM keeps only the `rationale` text. Do not move scoring back into the prompt : that
reintroduces run-to-run drift and false-green meters.

## Secret redaction

Brownfield Scout output is passed through `redact()` before it reaches any persona, the PRD, or
the persisted HTML/JSON. It strips key/token/JWT/AWS/Slack-shaped values and `user:pass@` URLs so a
shareable PRD never carries a literal credential out of the repo.

## Verify phase (v3)

`render_prd.py` does the structural checks itself and exits 1 on failure. Verify then reads the
prd-review linter score: under 85, one fix agent receives the linter findings, returns a corrected
PRD (same IDs, no new scope) and it is re-rendered once. No loop beyond that.

## Critic pass (balanced / deep modes)

After Synthesize produces a draft PRD, a separate critic agent (the reviewer
lane : it must not rewrite, only find faults) returns `{ findings: [{ severity, type, section,
issue, fix }], verdict }`. Finding types: `fabrication` (uncited claim), `scope-creep`,
`unverifiable` (criterion with no command/observable), `vague-goal` (describes code, not outcome),
`missing-risk`, `missing-nongoal`, and from v3 `bundled`, `missing-acceptance`, `missing-id`, `module-level-parity`, `no-unit`, `untagged-figure`, `unsized-scope`, `unmeasured-target`, `unbounded`, `silent-conflict`. A reviser then applies every med/high finding and returns the
final PRD; if there are no med/high findings the draft is kept. This enforces the
"never self-approve in the same context" rule : authoring and review are distinct agents.

Every run is deep (the user, 24 Sep 2026), so this pass always runs.

## Quality bar (Synthesize agent)

The 17 numbered rules in the synthesize prompt are the bar. In short: IDs everywhere; one capability
per requirement with MoSCoW and Given/When/Then; outcomes as metric/baseline/target; units and evidence
tags on every number; sized releases; disagreements recorded as decisions; plain words the linter
does not flag; no em or en dashes.

## HANDOFF PLAN format (`<slug>-handoff.md`, --handoff flag)

# <title>: execution plan
OBJECTIVE: what we're building and why (≤3 lines, from PRD problem+goal).
SUCCESS: checklist a model can verify: each item `[ ] <check>` with the exact
command or observable state (from PRD acceptance criteria).
MILESTONES: ordered phases (from PRD releases), one line each, each ends in a
verifiable state.
TASKS: small numbered steps grouped by milestone (one or more per FR ID). Each:
  `N. <verb phrase>` / Files: <paths> / Done when: <command or observable>.
  Sized so Sonnet finishes one task in one sitting without asking.
HANDOFF: conventions (naming, patterns, test framework), gotchas
(incl. PRD Open Questions as ASK-USER-FIRST), work order (strict task sequence
+ what to do when a done-check fails: stop, report, don't improvise).
