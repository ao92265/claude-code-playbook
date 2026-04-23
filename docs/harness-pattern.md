---
title: The Harness Pattern
nav_order: 41
parent: Architecture
---
# The Harness Pattern (and Why Vibe Coding Fails)

> The model is not the product. The harness around it is. — paraphrased from every third talk at AWS Summit London 2026

Most AI-assisted code review failures are not model failures. They are harness failures. This play captures the lessons that apply directly to Claude Code workflows: how to wrap the model in rules so it produces code your team can actually own.

For the layered definition of model / harness / rules and the four decision paths (Claude Code vs Agent SDK vs rules vs bare API), see [harness.md](harness.md). This play is the narrative companion — why the harness matters and how to tighten it when AI-generated code has to live in a codebase someone will still be maintaining next year.

---

## What a Project-Level Harness Is

A harness is everything around the model that decides what it can see, what it can do, what it must refuse, and how you prove afterwards that it behaved. In Claude Code terms, the harness is:

- Your `CLAUDE.md` and steering files
- The skills, tools and MCP servers you allow
- The content store the model can retrieve from
- The pre-commit hooks, code reviews and eval loops around the output
- The boundary between "Claude can touch this" and "Claude must not touch this"

Claude Code is already a harness around a raw LLM. The question this play answers is: how do you make your *project-level* harness good enough that Claude can help you modernise a legacy system without silently burying the team in debt?

---

## The Three Checks

From Owen Hawkins' CDL talk at AWS Summit London 2026. These belong on every PR description that contains AI-generated code.

1. **Steering.** Are your standards and practices enforced by files the model has to read, not folklore? If the answer is "we told it once in the prompt," that's not enforcement.
2. **Content store.** Can the model ground its changes in your actual code, docs and decisions, or is it working from training data and guesswork?
3. **Comprehension.** Can a human on the team read the generated code, explain it, and defend it in review? If not, do not merge it.

> "It compiles and the tests pass" is not the bar. "A human on this team can read it, explain it, and maintain it" is the bar.

---

## Steering Files: Rules, Not Vibes

A steering file is a set of house rules the model must code within. They are not suggestions. Put these in `CLAUDE.md` at the repo root:

- Language and framework versions (and which ones are banned)
- Allowed libraries and the reasoning (one line each)
- Architectural patterns and layering rules (what calls what)
- Test expectations (coverage target, framework, what must be mocked)
- House style points the linter cannot catch (naming, error handling shape, logging)
- Explicit "do not" list: deprecated APIs, libraries on the removal path, patterns from the legacy system that must not be reproduced

**Good steering rule:**

```
All new code must use the Result<T, E> return pattern for fallible operations.
Do not throw exceptions from service-layer functions. See docs/error-handling.md.
```

**Bad steering rule:**

```
Write clean code.
```

The difference is enforceability. The first can be checked in review. The second cannot.

**When to nest `CLAUDE.md` files.** One at the repo root for repo-wide rules. A second inside `services/payments/` for payments-specific rules (PII handling, audit logging, idempotency). Claude Code reads the closest one first. See [path-scoped-rules.md](path-scoped-rules.md) for directory-scoped loading order.

Deeper treatment: [steering-files.md](steering-files.md).

---

## Add a Content Store

If the model is guessing at your codebase, it will produce confident wrong answers. Give it somewhere to look.

Practical minimum for a modernisation project:

- An `ARCHITECTURE.md` that actually describes the current shape of the system
- A `DECISIONS/` folder of short ADRs (one per non-obvious choice)
- A `GLOSSARY.md` that defines domain terms, especially when migrating from a legacy system with its own vocabulary
- The legacy source, searchable, so the model can check "how did the old system do this?" before re-inventing behaviour
- Tests as executable documentation of expected behaviour

Claude Code + `Grep` across these is already a usable retrieval harness. MCP servers (Context7 for library docs, an internal-docs MCP for company knowledge) extend it further without blowing up the context window. See [mcp-servers.md](mcp-servers.md) and [knowledge-and-context.md](knowledge-and-context.md) for the retrieval side.

---

## The Comprehension Check (Anti-Vibe-Coding)

The single biggest risk in AI-assisted modernisation is that the pipeline produces code that works, no one on the team understands, and nobody is willing to touch in six months. This is vibe coding: shipping what the model produced because the vibes were right.

Stop it at review. Before merging AI-assisted code, the author must be able to answer, **in writing in the PR description**:

- What does this code do, in one paragraph, in your own words?
- Why this approach rather than the obvious alternative?
- Where would you put a breakpoint if it misbehaved in prod?
- What's the blast radius if this is wrong?

If any answer is "I'd ask Claude," the PR is not ready.

---

## Anti-Patterns

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| "The tests pass so it's fine" | Tests were also generated by the model; they test what was built, not what was needed | Write or review the tests against the requirement, not the implementation |
| Copy-paste-accept | Author cannot explain the code in review | Require a written explanation in the PR description |
| No steering file | Every change is a new negotiation with the model | Put the negotiation on disk, where it's versioned |
| "It compiles" as the bar | Compilation proves nothing about correctness | Raise the bar — comprehension + behaviour, not syntax |
| One giant generated PR | Impossible to review; incentive to rubber-stamp | Cap generated PR size; one bounded change at a time |
| Self-reviewed AI output | No independent signal | Human review of AI PRs is non-negotiable, and not by the person who drove the generation |

---

## Don't Mark Your Own Homework

Evaluations live outside the system being tested. If the same pipeline that generated the code also judged the code, you have no independent signal.

For a modernisation project that means:

- Property-based tests and contract tests written against the **original** behaviour, not the new implementation
- A separate test harness that replays real inputs through old and new code and compares outputs
- Code review by someone who didn't drive the generation
- Static analysis (linters, type checkers) as a disinterested third party

For teams building AI features, the same rule applies at runtime: the eval harness must be a separate service, with a separate prompt, ideally a different model. Do not ask the generating model whether its output was correct.

---

## For Anyone Building Agents on Top of Claude

Most of the chatbot-hardening lessons from the Summit lift one-for-one to Claude-based agents:

- **Scoped tool-calling.** The agent can only call a short, explicit tool list. If the model tries something else, the harness rejects the turn.
- **PII minimisation at the boundary.** Redact before the model sees it. Re-hydrate after.
- **Refusal as first-class behaviour.** Evaluate whether the agent refused appropriately, not just whether it answered.
- **Policy trigger-rate drift alerts.** When a guardrail suddenly fires twice as often, treat it as a production signal.
- **Canary prompts.** A handful of known-good and known-bad prompts injected continuously.
- **Persuasion-style red teaming.** Not just "abuse" prompts — social-engineering ones. The Zeng et al. jailbreak paper (below) gives a starting taxonomy (harmful prompts × persuasion strategies).
- **Version prompts and tools like code.** Roll them back independently from the model.
- **Structured tracing on every LLM turn.** Guardrail decisions, prompt, output and downstream calls in one trace.

See [regulated-ai.md](regulated-ai.md) for SR 11-7 / EU AI Act alignment and [cost-and-observability.md](cost-and-observability.md) for the tracing stack.

---

## Decision Tree — Harness, Rules, or Step Back?

```
Generating code for a new, low-stakes feature?
 └─ Steering file + PR review is probably enough.

Generating code that touches auth, payments, customer data, or safety?
 └─ Steering file + content store + scoped tools + named human reviewer.
    Generated code must come with a written comprehension note.

Generating code to replace a legacy system (VB6, COBOL, monolith)?
 └─ All of the above, plus:
    - Replay harness comparing old vs new behaviour on real inputs
    - No "big bang" PRs — one bounded capability at a time
    - ADR for every non-obvious migration decision
    - Independent review by someone who did not drive the generation

No one on the team can read the generated output?
 └─ Stop. The harness is too loose or the task is too big.
    Tighten steering, shrink the scope, or step back from AI assistance
    for this slice.
```

---

## Sources

- Owen Hawkins, *Lessons Learnt from CDL: Avoid Vibe Coding* — AWS Summit London, 22 April 2026
- Virgin Atlantic, *Building Concierge* (voice + text LLM concierge, OpenAI + LiveKit + Datadog LLMObs) — AWS Summit London, 22 April 2026
- Zeng et al., *How Johnny Can Persuade LLMs to Jailbreak Them* — referenced as the basis for Virgin Atlantic's persuasion red-team set

---

## See Also

- [harness.md](harness.md) — model / harness / rules layers and the four implementation paths
- [steering-files.md](steering-files.md) — writing enforceable house rules
- [templates/CLAUDE.md](../templates/CLAUDE.md) — starting point for a steering file
- [skills/code-review/](../skills/code-review/) — structured review skill; pair with the comprehension check
- [legacy-modernization.md](legacy-modernization.md) — characterisation tests and incremental migration
