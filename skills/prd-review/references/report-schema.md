# Report JSON schema (for render.py)

`render.py` turns this object into a self-contained HTML scorecard. Assemble it after the
review from the linter output plus your semantic adjustments. All fields optional except
`total` and `grade`; missing sections are simply omitted from the page.

```json
{
  "title": "Cadence",                       // PRD name, shown in the header
  "total": 88,                              // final reconciled score 0-100 (required)
  "grade": "B",                            // A-E (required)
  "verdict": "Strong, well-formed spec.",   // one line, shown large
  "detail": "The one real gap is acceptance criteria written as scenarios.",
  "baseline": 79,                          // the linter's structural total (optional)
  "adjustmentNote": "the coverage map earns back most of the testability marks",

  "cats": [                                 // one per category, in order
    {"name": "Structure & anatomy",            "score": 20, "max": 20, "note": ""},
    {"name": "Requirement quality",            "score": 22, "max": 22, "note": ""},
    {"name": "Testability (acceptance criteria)","score": 9, "max": 16, "note": "Coverage map credited; no Given/When/Then."},
    {"name": "Measurable NFRs",                "score": 12, "max": 12, "note": ""},
    {"name": "Decisions & governance",         "score": 15, "max": 18, "note": ""},
    {"name": "Anti-pattern cleanliness",       "score": 11, "max": 12, "note": "One unquantified 'fast'."}
  ],

  "rewrites": [                             // the weakest requirements, quoted + rewritten
    {"before": "FR-GANTT-5 — Bar colour reflects status (and/or assignee — TBD).",
     "after":  "FR-GANTT-5 (Must) — A bar's fill encodes status via the four-token scale; AC: …",
     "why":    "removes the TBD, ties to the a11y NFR, adds a testable criterion"}
  ],

  "topFixes": [                            // 1-3 highest-value fixes
    "Add Given/When/Then for the Must requirements, leading with denied/empty cases.",
    "Resolve the TBD in FR-GANTT-5.",
    "Promote the status line to a full Document Control block."
  ],

  "findings": [                            // linter findings + your added ones
    {"level": "fail", "msg": "No acceptance criteria as scenarios.", "ref": "§6"},
    {"level": "warn", "msg": "No version/document-control header.", "ref": "§11"},
    {"level": "pass", "msg": "63 functional-requirement IDs detected.", "ref": "§5"}
  ]
}
```

- `level` is one of `fail` / `warn` / `pass`; findings are auto-sorted fail-first.
- Keep `cats` in the six-category order and use the same `max` values as the rubric
  (20 / 22 / 16 / 12 / 18 / 12) so the bars and total line up.
- All text is HTML-escaped by the renderer; write plain text (quotes are fine).
