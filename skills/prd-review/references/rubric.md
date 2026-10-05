# PRD scoring rubric

Six categories, 100 points. Score each against the "strong entry" description. The bundled
linter (`scripts/score.py`) gives a mechanical baseline; this rubric is what you judge against
when adjusting it.

| # | Category | Points | Scores what |
|---|----------|:------:|-------------|
| 1 | Structure & anatomy | 20 | The core sections are present |
| 2 | Requirement quality | 22 | Requirements are capabilities, ID'd, prioritised |
| 3 | Testability (acceptance criteria) | 16 | Each requirement can be proven pass/fail |
| 4 | Measurable NFRs | 12 | Quality attributes have numbers + methods |
| 5 | Decisions & governance | 18 | Version control, decisions, risks |
| 6 | Anti-pattern cleanliness | 12 | No subjective adjectives / vague quantifiers / filler |

---

## 1. Structure & anatomy (20)

**Core sections** (each worth ~2): Summary · Problem & users · Goals · Non-goals · Success
metrics · Functional requirements · Acceptance criteria · Non-functional requirements ·
Decisions / open questions · Risks & assumptions.
**Context sections** (small bonus): data & authorisation model · information architecture ·
domain/compliance · glossary.

Strong: every core section present and non-empty. Weak: no non-goals (scope creep waiting to
happen), no success metrics, no risks.

## 2. Requirement quality (22)

Each functional requirement is a **capability, not an implementation**, carries a **stable ID**
(e.g. `FR-AUTH-1`), and has a **priority** (MoSCoW: Must/Should/Could/Won't — or tiers
MVP/MLP/Beyond).

- **Good FR:** "Users can reset their password via an email link." (observable capability)
- **Bad FR (leakage):** "System sends a JWT via email and validates against the users table."
- Hold each to SMART: Specific, Measurable, Attainable, Relevant, Traceable.
- Deduct for technology names, library choices, or DB details inside the requirement.

## 3. Testability (16)

Every requirement can be turned into a pass/fail test. The standard form is **Given / When /
Then**, and it must include the **awkward cases** — empty input, wrong permission/tenant,
already-done action — not just the happy path.

- A **coverage / traceability map** that ties each requirement to a test layer also satisfies
  this even without Gherkin — credit it.
- Happy-path-only scenarios are thin; dock them.

## 4. Measurable NFRs (12)

Template: **"The system shall &lt;metric&gt; &lt;condition&gt; as measured by &lt;method&gt;."**

- **Good:** "API responds in under 200ms at p95 under normal load, per APM." / "99.9% uptime
  in business hours per the cloud SLA."
- **Bad:** "The system shall be scalable / fast / highly available." (untestable)
- A number that isn't a real target ("supports 1 user") does not count as measurable.

## 5. Decisions & governance (18)

- **Version / document control** header: version, status, owner, date; and for an evolving PRD,
  what it inherits / supersedes.
- **Decision records** with rationale and the accepted trade-off (Question · Decision · Why ·
  Trade-off · Closed).
- **Risks** rated with likelihood, impact and a concrete mitigation — ideally one that becomes
  a test.
- Open questions carry owners and blocking status.

## 6. Anti-pattern cleanliness (12)

Starts at 12; deduct for each occurrence, floored at 0.

- **Subjective adjectives:** easy to use, intuitive, user-friendly, seamless, fast, robust,
  scalable, powerful, modern (when not backed by a number). → replace with a metric.
- **Vague quantifiers:** multiple, several, various, some, many, a few, etc. → give the number
  or the enumeration.
- **Filler / weasel:** "in order to", "it is important to note", "the system will allow users
  to", "be able to", "where appropriate", "if possible". → state the fact directly.

---

## Functional vs design PRDs

Categories 1, 2, 5 and 6 apply to any PRD. Categories 3 and 4 are read differently by document type:

- **Functional / product PRD** — Testability = Given/When/Then acceptance criteria. Measurable
  NFRs = latency, uptime, throughput, size targets.
- **Design / UX PRD** — Testability = a **definition of done** (what "done" means for a screen /
  component) plus **checkable design metrics** (0 hardcoded tokens, 100% AA, all four states per
  screen, 0 legacy chrome). Measurable NFRs = **accessibility and token targets** (WCAG level,
  contrast, 44–48px, dynamic type, reduced motion), not server latency.

Don't dock a design PRD for lacking Gherkin, or a functional PRD for lacking a token-compliance
metric. The linter's `--mode` switches these two categories; make sure it matched the document.

## Grade bands

| Score | Grade | Meaning |
|------:|:-----:|---------|
| 90-100 | A | Well-formed and rigorous. Ready for review. |
| 80-89  | B | Solid; a few gaps to close before sign-off. |
| 70-79  | C | Serviceable but leaky; several checks failing. |
| 55-69  | D | Structurally incomplete; core pieces missing. |
| 0-54   | E | Not ready; treat as a first draft. |

A high score means the document is **well-formed and buildable**, not that it describes the
**right product**. That second judgement is a separate conversation — flag it if it matters.
