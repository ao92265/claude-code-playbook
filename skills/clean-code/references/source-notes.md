# Source and interpretation

Basis: Robert C. Martin and contributors, *Clean Code: A Handbook of Agile Software Craftsmanship*, ISBN 978-0-13-235088-4. Copyright 2009, first printing July 2008. Page references below are printed book pages.

The review covered the contents, substantive guidance across chapters 2–13, selected case-study passages in chapters 14–16, the chapter 17 heuristic catalogue, and relevant concurrency appendix passages. The case studies and source-code appendices were not line-by-line audited. The skill contains original operational guidance and examples; the book/PDF and extracted text are not bundled or required at runtime.

| Source | How it informs this skill |
| --- | --- |
| Ch. 2, pp. 17–30 | Names communicate domain intent and avoid misleading distinctions. |
| Ch. 3, pp. 31–52 | Cohesive functions, abstraction levels, explicit effects, comprehensible arguments, and iterative refinement. |
| Ch. 4, pp. 53–74 | Remove misleading commentary while retaining rationale, warnings, legal notices, and useful API documentation. |
| Ch. 5, pp. 75–92 | Format for communication and respect the team's conventions. |
| Ch. 6, pp. 93–102 | Hide implementation knowledge; choose objects or plain data according to how the code needs to change. |
| Ch. 7, pp. 103–112 | Keep failure handling understandable and preserve contextual information. |
| Ch. 8, pp. 113–120 | Keep third-party details near the boundary; verify the contract the application actually uses. |
| Ch. 9, pp. 121–134 | Treat tests as maintained code; prefer one coherent concept per test and reliable feedback. |
| Ch. 10, pp. 135–152 | Cohesion, responsibility, and reducing the impact of changes. |
| Ch. 11, pp. 153–170 | Separate construction from use and keep infrastructure from overwhelming domain logic. |
| Ch. 12, pp. 171–176 | Verify behaviour, express intent, reduce duplication, and minimize unnecessary classes/methods. |
| Ch. 13, pp. 177–192; Appendix A, pp. 317–348 | Isolate concurrency, reduce shared state, protect compound operations, and exercise failure/shutdown paths. |
| Ch. 14, especially pp. 200, 212–213, 250 | Evolve a working implementation through small tested transformations. |
| Ch. 15, especially pp. 252, 265 | Use tests to understand behaviour and reverse an extraction when a later design reads better. |
| Ch. 16, especially pp. 268–270, 283–284 | Establish behaviour before structural cleanup; coverage alone does not establish quality. |
| Ch. 17, pp. 285–315 | Diagnostic vocabulary for names, duplication, misplaced responsibilities, temporal coupling, boundaries, and tests. |

## Deliberate adaptations

The book often presents strong preferences in a Java/OO setting. This skill treats them as prompts for judgment and uses the target language's idioms:

- No fixed function length, argument limit, assertion count, or coverage target. The book itself discusses one concept per test (pp. 131–132) and excessive tiny classes/methods (p. 176).
- Preserve explicit parameters instead of moving dependencies into shared fields simply to reduce arity.
- Use exceptions, typed results, optional values, and sentinel conventions according to the language and contract. Do not universally replace error returns or absence with exceptions.
- Use functions, records, tables, pattern matching, components, or classes as appropriate. A switch or DTO is not inherently a defect; chapter 6 explicitly discusses tradeoffs between data and objects.
- Follow the repository's import and formatting tools rather than adopting Java-specific wildcard-import guidance from chapter 17.
- Do not split atomic check-and-update operations merely to enforce command/query separation.
- Confirm intended requirements before changing supposedly obvious behaviour. Some book case studies mix defect fixes and refactoring; this skill identifies them separately.
- Use syntax-aware tools where available and trace complete feature flows. These execution mechanics, scope rules, and publishing boundaries are this skill's design choices rather than claims made by the book.
