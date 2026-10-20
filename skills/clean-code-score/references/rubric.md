# Rubric v1.0 — Clean Code alignment

Nine categories, 100 possible points before applicability adjustments. This is an original weighted assessment derived from the book; the book provides no numerical scoring rubric. Chapter/page references use printed book pages.

| ID | Category | Weight | Source |
|---|---|---:|---|
| names | Names and expressed intent | 10 | Ch. 2; Ch. 17 N1–N7, G19–G20, G25 |
| functions | Focused functions and explicit effects | 15 | Ch. 3; Ch. 17 F1–F4, G6, G30–G31 |
| cohesion | Cohesion, encapsulation and change isolation | 15 | Ch. 6, 10–11; Ch. 17 G7–G8, G13–G17, G36 |
| simplicity | Duplication and design simplicity | 10 | Ch. 12, 14–16; Ch. 17 G5, G9, G12 |
| errors | Error handling and outcome clarity | 10 | Ch. 7; Ch. 17 G3, G26 |
| boundaries | Dependencies, construction and external boundaries | 10 | Ch. 8, 11 |
| tests | Test quality and safe change | 20 | Ch. 9, 12; Ch. 17 E1–E2, T1–T9 |
| presentation | Comments, formatting and local readability | 5 | Ch. 4–5; Ch. 17 C1–C5, G10–G11, G24 |
| concurrency | Concurrency and shared-state discipline | 5 | Ch. 13; Appendix A |

## Common rating anchors

Use integer ratings, supported by both the category criteria and actual inspected code. Do not count checklist items mechanically or deduct points per text match.

| Rating | Meaning | Evidence needed |
|---:|---|---|
| 4 | Consistently strong in the inspected scope | Representative implementations and associated callers/tests establish the principle, with no material counterexample in that sample. |
| 3 | Mostly aligned | Strong typical practice with isolated, localized problems; identify those problems. |
| 2 | Mixed | Meaningful strengths and recurring weaknesses, or an important area needs substantial improvement. |
| 1 | Mostly weak | Widespread weaknesses with only limited working examples of the principle. |
| 0 | Absent or fundamentally broken | Direct evidence establishes a systemic absence or failure of the applicable practice. |
| unknown | Not assessable from available evidence | State the missing access, sampling gap, or ambiguity. Never translate this into 0 or 4. |
| na | Truly does not apply | State why the scope has no relevant instance. Never use this to excuse a missing practice. |

For each rating, explain prevalence in the inspected scope. Confidence measures evidence strength, not code quality: high = direct implementation/caller/test evidence across representative paths; medium = some triangulation or a restricted sample; low = thin/indirect evidence. Use unknown when evidence cannot support a rating at all.

## Category-specific criteria

### names — 10

Strong: names convey purpose, domain concepts, units and effects; terminology is consistent; scope supplies useful context. Readers need little mental decoding. Weak: misleading operation names, inconsistent words for one concept, indistinguishable parameters or unexplained policy literals recur. Inspect usages, not just declarations. Conventional short indices in tiny scopes are fine.

### functions — 15

Strong: operations have one coherent purpose and a readable abstraction level; data flow and effects are explicit; arguments make sense at call sites; lifecycle/order requirements are visible. Weak: unrelated work mixed into functions, hidden mutation, confusing flag modes, or undocumented sequencing recur. Length and arity identify candidates only. Cohesive algorithms may be long; commands may return results; never reward moving arguments into hidden shared state.

### cohesion — 15

Strong: modules own cohesive responsibilities, hide changeable representation and expose useful contracts; policy lives with its owner; changing a rule has limited impact. Weak: unrelated reasons to change, callers manipulating internals, artificial dependency cycles, or broadly exposed mutable implementation state. Inspect real dependency and call paths. Plain data structures, functional modules and components can earn full marks without classes. Dot chains alone do not prove a violation.

### simplicity — 10

Strong: business knowledge has a clear owner, similar code is shared when its change reason is shared, and abstractions remove real complexity. Weak: policies must be synchronized manually, verified dead code obscures active paths, or speculative interfaces/wrapper chains add navigation. Similar text with different business reasons is not necessarily duplication. Avoid penalizing a cohesion problem twice; use this category for distinct duplicated policy or needless machinery.

### errors — 10

Strong: expected absence, invalid input and operational failure have useful distinct meanings; context reaches callers; recovery and resource cleanup are clear. Weak: broad catches hide failure, failures become success values, context disappears, or partial failures leave inconsistent state. Examine failure paths and callers. Follow idiomatic exceptions, result types, optional values, error returns and cleanup constructs. Null/None or error returns are not inherently defects.

### boundaries — 10

Strong: external/library contracts are confined where useful, construction is separable from business use, and time/I/O/configuration can be controlled for meaningful tests. Weak: vendor details spread through domain rules or hidden concrete dependencies obstruct testing/change. Direct library calls in an adapter are fine; an interface per class or a DI framework is not required. A self-contained library still has dependency/construction decisions: do not mark this NA merely for lacking a database.

### tests — 20

Strong: readable behavior tests cover representative rules, boundary/failure cases and relevant integration contracts; tests are isolated, repeatable, self-validating and provide practical feedback; build/test entry points are clear. Weak: major rules lack meaningful checks, fixtures leak state, tests depend on order/network/time unnecessarily, or assertions mirror private implementation. Read assertions and production paths. Coverage and green CI alone cannot establish quality. Multiple assertions for one concept are fine. Existing failures need diagnosis; unavailable tooling is an unknown execution result. Confirmed absence of tests for substantial behavior is evidence for a low rating, not unknown. Do not require unit tests for inert declarations or infer historical TDD from test files.

### presentation — 5

Strong: conventions and layout help navigation, comments explain intent/constraints, and public contracts have useful documentation where needed. Weak: contradictory/stale comments, large commented-out implementations, inconsistent local formatting or misleading narrative obscure the code. No mandatory comment ratio or Java import rule; retain legal and operational notices. Distinct misleading names belong in names, rather than being charged here again.

### concurrency — 5

Strong: concurrent work is isolated, shared mutation is limited, compound invariants are protected, and ordering, failure, cancellation/shutdown have explicit contracts and suitable tests. Weak: unprotected shared updates, hidden ordering dependencies or fragile lifecycle handling. Assess threads, asynchronous reentrancy, workers and overlapping operations where relevant. Async syntax alone proves neither safe nor unsafe concurrency. Single-threaded request handlers may still share state across awaits. NA requires evidence that the reviewed scope has no meaningful concurrent work or shared-state exposure; incomplete inspection means unknown.

## Calculation and grade bands

For applicable assessed category i: points_i = weight_i × rating_i / 4.
Let A = sum of assessed weights, U = sum of unknown weights, P = A + U (all applicable weights). NA weights are excluded from P.

- Assessed score = 100 × sum(points_i) / A, rounded to one decimal. Report assessed coverage = 100 × A / P.
- Unknowns produce an uncertainty interval: lower = 100 × sum(points_i) / P; upper = 100 × (sum(points_i) + U) / P. This is a possible-score interval, not statistical confidence.
- If A / P is below 70%, withhold an overall score/grade and show “insufficient evidence”, plus the interval and category results. If P is zero, no score is possible.
- At 70% or above, show the assessed score. Unknown categories make it provisional. Sampled scopes always remain labeled sampled/provisional, even with 100% assessed category weight.
- Grade the rounded displayed score: A = 90–100, B = 80–89.9, C = 70–79.9, D = 55–69.9, E = below 55. Bands mean very strong / strong / mixed / weak / very weak alignment in the reviewed scope. They do not authorize deployment or constitute certification.

Example: all ratings 3, concurrency NA → 71.25/95 raw points → 75.0/100, C. If tests are additionally unknown: 56.25/75 assessed points → 75.0, C, provisional; assessed coverage 78.9%; possible full-applicable score 59.2–80.3.
