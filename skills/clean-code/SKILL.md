---
name: clean-code
description: Review and improve existing code, modules, or complete feature flows using pragmatic Clean Code principles. Use for readability, responsibility, coupling, error handling, duplication, or testability refactors. Honor review-only requests; otherwise implement and verify scoped improvements.
---

# Clean Code

Make the supplied code easier to understand and safer to change while preserving its established behaviour. Apply the book's principles with language and repository judgment. Each change needs an observed problem, a concrete benefit, and proportionate verification. Leaving good code alone is a valid outcome.

## Choose the scope and action

- For an explicit review or audit, inspect and report findings without editing. For requests to clean up, refactor, or improve, implement useful changes and verify them. Respect narrower user constraints.
- Target the supplied snippet, file, module, or feature. If no target is given, inspect the current task/diff and repository context; ask only when there is no defensible target. Do not interpret a vague request as authorization to rewrite the repository.
- Read repository instructions and conventions, inspect the working tree, and preserve unrelated work. Exclude generated, vendored, and minified files unless they are the explicit target; change their source instead when appropriate.
- This skill authorizes no publishing, PR creation, or merge by itself. Follow separate user instructions for delivery. If FullSend is also explicitly requested, use this skill for the improvement work within that delivery workflow.

## Understand before changing

Use the repository's parser, compiler, language server, AST tooling, or symbol search when available. Start file and text discovery with `rg`; text matches identify candidates, not proof of semantics or dead code. Do not install a new analysis stack unless it materially helps. Read actual definitions, call sites, and tests.

Adjust the inspection to the target:

| Target | Inspect | Preserve |
| --- | --- | --- |
| Snippet/function | Inputs, outputs, branches, state changes, direct callers, examples/tests | Values, mutation, exceptions, ordering, short-circuit and evaluation behaviour |
| Module/package | Exports, callers, ownership of state, dependency direction, external integrations | Public API, import paths, data shapes, initialization and resource lifetimes |
| Feature | Trace a real entry point through validation, business rules, persistence/integrations, response/UI, and tests | User-visible results, authorization, transactions, failure paths, compatibility |

A feature is a flow across files, not merely the directory with its name. Follow only relevant paths. Distinguish confirmed relationships from unresolved dynamic dispatch, framework registration, or unavailable dependencies. With an isolated snippet, state which caller assumptions cannot be verified.

Establish existing validation and run a useful baseline before a substantial refactor. Separate pre-existing failures from introduced failures. If coverage is weak for a risky change, add focused characterization tests for externally observable behaviour first. Do not codify an apparent bug as desired behaviour: distinguish observed behaviour from the intended contract and report the discrepancy.

## Diagnose and select improvements

Read [patterns.md](references/patterns.md) for evidence, remedies, and counterexamples. Read [verification.md](references/verification.md) when selecting checks for state, boundaries, asynchronous work, or feature flows. Consult [source-notes.md](references/source-notes.md) when explaining the book's basis or its adaptations. [worked-example.md](references/worked-example.md) demonstrates a small behaviour-preserving refactor.

For each candidate identify:

1. The concrete location and observed pattern.
2. The comprehension burden, change coupling, failure risk, or testing difficulty it creates.
3. The smallest useful remedy and any contract it could affect.
4. The evidence that will demonstrate preservation or the explicitly requested correction.

Prioritize correctness risk exposed by the review, then repeated change hazards and substantial readability improvements. Label a discovered defect separately from a refactor. Fix defects only within the authorized scope and with evidence for intended behaviour; otherwise report them. Do not silently invent product rules.

Use function length, parameter counts, nesting, fan-out, and coverage as clues, never mandatory targets or a cleanliness score. Avoid blanket rules: tiny functions, exceptions everywhere, no nulls, one assertion per test, universal interfaces, and polymorphism for every branch.

## Refactor in small verified steps

- Change one coherent responsibility or rule at a time. Prefer local naming/control-flow improvements before introducing a new abstraction. Extract a function or module when its name and boundary remove knowledge a caller previously needed.
- Consolidate duplicated knowledge that should change together. Keep coincidentally similar code separate when its business reasons differ. Retain simple data structures and idiomatic functional, procedural, or component code where they fit.
- Preserve public signatures, serialized fields, framework hooks, persistence semantics, error contracts, side effects, transaction boundaries, and async ordering unless the requested task includes a change. Internal renames still require checking imports, reflection, fixtures, and registrations.
- Keep dependencies explicit; never move parameters into mutable shared state merely to reduce arity. Keep required rationale, legal notices, and operational warnings when editing comments.
- Use the existing formatter and language idioms on affected code. Avoid unrelated formatting churn, dependency upgrades, framework migrations, speculative extension points, and new dependencies for aesthetic cleanup.
- Run focused verification after each meaningful structural step. If behaviour changes unexpectedly, repair or revert your step before continuing. When evidence is insufficient, limit the change to what can be established and report the remaining gap.

## Final pass and report

Read the complete resulting diff and trace the affected callers/feature path again. Check that the change reduces the stated problem without adding disproportionate indirection, wider interfaces, or hidden state. Remove your abandoned scaffolding. Run the relevant existing tests and required repository checks; broaden verification when the affected dependency surface warrants it.

For an implementation, report the main changes with file links, why they help, checks actually run and results, and material remaining risks or deferred findings. For a review, lead with actionable findings ordered by impact, with locations, evidence, and proposed remedies; say when no worthwhile issues were found. Do not claim behaviour preservation based only on parsing, lint, compilation, or passing tests of unrelated paths.
