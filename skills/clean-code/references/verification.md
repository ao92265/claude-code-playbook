# Verification by risk

Select checks for what could change, not for a fixed test quota. Inspect existing commands and test boundaries first. Verify a baseline for substantial structural work and distinguish existing failures. Keep tests that protect real contracts; do not add tests for a purely local rename that the compiler and existing suite already cover.

| Change | Useful evidence | Common blind spot |
| --- | --- | --- |
| Rename/move symbol | Symbol consumers, compilation/type checks, relevant tests, registrations/imports | Reflection, plugin names, serialized keys, external consumers |
| Rewrite conditions or extract algorithm | Existing behaviour tests; empty, boundary, invalid, and representative inputs; equivalence/property checks when practical | Short-circuit effects, evaluation order, floating-point/rounding differences |
| Consolidate a policy | Tests at each affected caller and its exceptional cases | Similar-looking rules have different business contracts |
| Move state or isolate I/O | Outputs plus interaction effects, mutation/identity where relevant, cleanup and failure tests | Copying versus mutating, resource ownership, hidden initialization |
| Change error structure | Error type/result, context/cause, propagation, response mapping, cleanup | Empty success values that hide faults; caught errors that used to propagate |
| Split a module | Public consumers, dependency/build checks, affected integration tests | Import-time behaviour, circular dependencies, dynamic hooks |
| Refactor a feature flow | Representative success and failure paths through the actual entry point; permissions, validation, persistence, response/UI | Unit tests of helpers without verifying wiring or enforcement |
| Alter concurrency/async structure | Controlled interleavings, cancellation/shutdown paths, invariant checks; relevant stress/race tools if available | Passing a few repeated runs does not prove race freedom; extracting locks can alter atomicity |
| Performance-sensitive path | Representative timings or existing benchmarks where performance may be affected | Cleaner allocation/iteration patterns can regress memory, latency, or query counts |

Characterization tests capture the actual observable contract before a structural change. Include side effects where they matter. If actual behaviour disagrees with requirements, identify a defect; do not quietly fix it or bless it as intended just to simplify the refactor.

For a small pure calculation, comparison against the original over representative inputs may give useful supporting evidence. For an external boundary, test the contract against a realistic fake or available integration environment; do not mock away the operation whose behaviour is in question.

After implementation, inspect the complete diff and run focused tests plus required repository checks. Broaden when changed exports or integration paths warrant it. Report exact commands and results, unavailable environments, and any contract that remains unverified. Keep the change smaller when evidence cannot support a broader refactor.
