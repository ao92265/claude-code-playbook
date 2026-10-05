# Innovation Team Executive Summary: writing guidance

Distilled from the lab lead's InnovationLab Executive Summary Template (the structure used across the project-a, project-b and project-c summaries). Samples are from Project project-c (April 2026), as given in the template.

**Audience:** senior leadership who did not follow the build and will decide, from this document alone, whether the approach is credible and should be repeated.

## Ground rules (apply everywhere)

- 10 to 16 pages. Longer and the Financial Summary stops being read.
- Every number traceable to a repository, dashboard, dated artefact or stated assumption. Give the capture date for anything counted from a repo.
- Name the benchmark and its provenance. "COCOMO II" or "internally benchmarked against comparable enterprise tools" both work. "Industry standard" alone does not.
- Separate build cost from runtime cost, and delivery savings from customer-side savings.
- Report at least one thing that went wrong, with numbers and root cause.
- Pick British or American spelling and hold it.
- Round honestly: "approximately 38,000 USD", never "37,842 USD".

## Cover

Codename first, plain-English descriptor second: a stranger should know what it is from three lines. Every author with country and reporting line (cross-border and seconded setups are part of the story). Month and year; version in the footer. Classification: Internal by default, Commercial in Confidence when customer names, tender positions or pricing appear.

> Sample: PROJECT project-c / AI-Assisted Drug Catalog Editor / MetaVision 5, Hospital Catalogs or National Drug Catalogs to MetaVision 6 Migration Platform. the lab lead, Innovation Team, Parent Group, Germany. Liran Sellam, Secondant Innovation Team, seconded from iMDsoft, Israel. April 2026. Internal.

## Financial Summary (1 page, write it LAST)

The only section guaranteed to be read. Four to six sentences carrying the whole argument: what was delivered, elapsed time, team size, benchmark, saving in absolute and percentage terms. Footnote the blended rate per developer-month and say it is applied to both scenarios. Split tooling cost from personnel. Keep customer-side runtime cost out of the delivery figure and label it an operating cost.

> Sample: Delivered in approximately six weeks with two developers, against an internally benchmarked traditional estimate of four to six months with five to seven developers: three times smaller in team size, four to six times faster. At 12,500 USD per developer-month applied to both scenarios, total delivery cost was approximately 38,000 USD against a benchmark of 250,000 to 525,000 USD, an 85 to 93 percent saving. Tooling ran at 500 USD per month. Runtime inference of approximately 30 USD per catalog import is a customer-side operating cost. (project-b framed it as 6 developers over 26 months at 1.5M GBP vs 2 developers over 1 to 2 months at 80k GBP, benchmark validated with COCOMO II.)

**Time Investment Analysis:** one row per phase, traditional vs actual. Show testing and documentation as continuous or generated alongside code. Add a note on lost time (holidays, late secondments, access delays).

> Sample note: Week 4 coincided with Easter in Germany and Passover in Israel, on different days, so the team lost close to a week of synchronous overlap. The asynchronous AI-assisted workflow absorbed it.

## Part 1: Project Overview (1 page)

- **What is it:** three to five sentences, no unexpanded acronyms. What it does, who operates it, what it replaces, deployment model (and any residency or regulatory constraint). One screenshot of the primary screen.
- **The Problem:** four to six bullets quantified in units the business tracks (months of specialist effort, cost per project, error rates, lost tenders). Name the legacy technology. Close with the commercial consequence.
- **Our Solution:** five to eight traits, not features. Lead with the design idea. If AI is both the build engine and inside the product, say so here in one sentence.

> Sample: Drug catalog configuration is the single largest time and resource cost in MetaVision projects. MV6's substance-centric model makes conversion a modelling exercise, not a field map. Typical cost is three to four months of specialist effort per customer, and losing this differential has cost tenders.

## Part 2: Scale of Work Completed (1 page)

Capture date and completion percentage before the table, and what the remainder is. The third column translates each number for a non-engineer. Pair lines of code with tests, PRs, review coverage and migrations. State the human review rate explicitly: for an AI-assisted build it is the most reassuring number in the document. 12 to 18 rows; drop any row you cannot regenerate.

**Review rate, honestly:** only count a review by a person other than the PR author. A review posted from the author's own account (commonly an agent session) is not independent review, and a bot review is not human review. If the independent figure is low, say so and explain the actual gate.

> Sample rows: project-c: 369 commits from 11 March, about 12 per day. 93 PRs, 100 percent human review before merge. 62 EF Core migrations. project-a: 73 percent coverage. 5 languages.

## Part 3: Technical Architecture (1 to 2 pages)

Tables for backend, frontend, AI runtime (only if the product calls models at runtime) and infrastructure. "Why This Choice" is the section: one line, operational grounds (what it makes easy, what risk it removes). Say where a choice exists to support AI-assisted development (structured JSON logs so a model can read them). Keep versions. If the AI runtime table does not apply, delete it and say so in Part 4; never leave it empty. If it does apply it must answer: where the keys live, cost per unit of work, how hard a provider change is.

## Part 4: The AI Approach (1 to 2 pages, the section the document exists for)

Separate AI as build engine (delivery economics) from AI inside the product (security, cost control, vendor risk). For the build engine: what it produced (requirements, plan, code, tests, docs), how work was structured, and the review rate. For runtime AI: governance first (keys, boundary, provider swap). Using the BU's internal gateway is a material fact; direct external calls from a customer deployment will be challenged.

> Sample: Claude Code was the primary engine throughout: requirements analysis, the PRD and 13-phase plan on day two, most code via feature-branch PRs, tests alongside code, documentation in parallel. Every PR human-reviewed: 93 over about six weeks.
> Key decisions sample: Speed: batching 15 to 50 items per call with 4 to 12 workers cut LLM round-trips about 25 times. Reliability: exponential backoff on rate limits, which the gateway wraps in HTTP 500, so explicit detection was needed.

## Part 5: Security and Integration (1 page)

Deployment model in two to four precise sentences about what leaves the customer environment ("Secure by design" is not a sentence a reviewer can act on). Security layers: name the mechanism, not the category; include correlation, audit and provenance for regulated data. Human-in-the-loop rule: state it and where it is enforced (model or dependency chain beats "the UI asks").

> Sample: No record can be exported without explicit pharmacist approval. The dependency chain enforces it at the model level: a Medication cannot be approved until its Ingredients, Dose Forms and Routes are. AI suggestions carry confidence and source, never silently written as fact.

## Part 6: Core Features (1 to 2 pages)

Five to eight numbered features in the order a user meets them. Behaviour and consequence, not screens. Auditability, provenance and workflow gating get their own entries even though they do not demo well.

> Sample: Provenance Tracking: FieldProvenance records, for every field of every entity, where its value came from: IMPORTED, AI_SUGGESTED (with confidence), USER_ENTERED, DEFAULT, EMPTY (a quality gap). The most important data-quality feature for clinical auditors.

## Part 7: The Invisible Excellence (1 page)

Answers "an AI wrote it, is it any good" with counts and tool names. Testing (by layer, and whether integration tests hit real dependencies), code quality, observability, documentation (generated alongside code, with line counts).

## Part 8: Challenges and Mitigations (1 page, most-read after Financial Summary)

Technical and Organisational, two to four entries each: heading, problem in numbers, root cause, mitigation. Report the genuinely bad failures. For technical entries say whether the fix was a better prompt or a different division of labour between deterministic code and the model; that is the transferable lesson. Organisational challenges (distribution, time zones, secondments, knowledge gaps) on equal footing. Name platform gaps constructively and specifically.

> Sample: First run gave 0 percent route accuracy and 3 percent dose-form accuracy. Root cause: too much freedom for the model. Fix: deterministic rules for everything predictable, the model only for genuinely ambiguous calls. Three quality sprints, a gold dataset and an eval harness got accuracy above the 70 percent target.
> Sample: One developer had no pharma background, the other had never used AI tooling. Both gaps closed in week one via in-repo context files and pairing. Signal: no prior AI experience needed.

## Part 9: Value Delivered (1 to 2 pages)

Three separate stories: internal delivery savings, customer-side value (the one leadership cares about most, it repeats per deal), commercial case (show the arithmetic, name where and when it was presented). Keep horizons explicit: "about 100,000 USD per year" and "200,000 to 400,000 USD over three years" are different claims.

## Part 10: Next Steps (half a page)

Must account for exactly the remainder in Part 2. Finishable bullets with owner and period. Close with first user feedback stated as a pattern, not a score.

## Appendix (half a page)

Ranked table of 15 to 20 substantive repo documents with line counts and purpose, then in-repo resources that are not documents (agent context files, decks, kickoff material).
