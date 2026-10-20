# Source traceability and interpretation

Source: Robert C. Martin and contributors, *Clean Code: A Handbook of Agile Software Craftsmanship*, ISBN 978-0-13-235088-4. First printing July 2008, copyright 2009 Pearson. Page numbers are printed page numbers.

| Chapters | Printed pages | Assessment use |
|---|---|---|
| 1 | 1–16 | Readability and the maintenance cost of unclear code motivate the review. |
| 2 | 17–30 | Domain intent, consistent vocabulary, useful context and searchable names. |
| 3 | 31–52 | Coherent functions, abstraction levels, understandable arguments and explicit effects. |
| 4–5 | 53–92 | Useful explanatory comments and formatting that supports reading. |
| 6 | 93–102 | Representation hiding and the tradeoff between objects and plain data. |
| 7 | 103–112 | Caller-oriented failure contracts, context and absence handling. |
| 8 | 113–120 | Contain external contracts and test the boundary the application uses. |
| 9 | 121–134 | Maintainable tests; fast, independent, repeatable, self-validating feedback; one concept per test. |
| 10–11 | 135–170 | Cohesion, reasons to change, construction versus use and dependency isolation. |
| 12 | 171–176 | Working behavior, less duplication, expressed intent and minimal unnecessary machinery. |
| 13; Appendix A | 177–192; 317–348 | Concurrency ownership, shared data, atomic operations, lifecycle and test strategies. |
| 14–16 | 193–284 | Iterative refinement with tests; worked examples inform review rather than additional scoring categories. |
| 17 | 285–315 | Cross-check vocabulary for smells, boundaries, temporal coupling, names and tests. |

The numerical weights, rating anchors, uncertainty treatment, sampling protocol, report format and grade bands are original skill design decisions. They are not claimed to be the author's rubric. The book's worked source listings and appendices are not reproduced or bundled.

This rubric follows the intent of the book while adapting Java/OO examples to the target language. It deliberately avoids universal thresholds for function size/arity, single-assertion quotas, required exception use, mandatory classes/interfaces, blanket rejection of nulls, or mandated polymorphism. Where useful, disclose the relevant adaptation in the report. This is an adapted alignment measure, not a literal compliance test for every prescription in the book. Static code cannot establish historical TDD, team habits, or continuous improvement without additional evidence.
