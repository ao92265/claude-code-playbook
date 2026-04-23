---
title: Steering Files
nav_order: 42
parent: Architecture
---
# Steering Files

A steering file is a set of house rules the model must code within. Not suggestions. Not folklore. Rules the model has to read every session, that a reviewer can point at when the PR violates them.

For the wider harness framing (why steering matters alongside a content store and a comprehension check) see [harness-pattern.md](harness-pattern.md).

---

## The Enforceability Test

If a rule can't be checked in review, it's not a rule. It's a wish.

**Good steering rule:**

```
All new code must use the Result<T, E> return pattern for fallible operations.
Do not throw exceptions from service-layer functions. See docs/error-handling.md.
```

**Bad steering rule:**

```
Write clean code.
```

One is enforceable. The other is a vibe.

---

## What Belongs in a Steering File

Put these in `CLAUDE.md` at the repo root:

- **Language and framework versions** — and which ones are banned
- **Allowed libraries** — each with a one-line reason
- **Architectural patterns** — layering rules (what calls what)
- **Test expectations** — coverage target, framework, what must be mocked, what must not
- **House style the linter cannot catch** — naming shape, error-handling shape, logging shape
- **Explicit "do not" list** — deprecated APIs, libraries on the removal path, legacy patterns that must not be reproduced

Things that do **not** belong: general programming advice ("write good code"), platitudes, duplicated linter rules, anything that would apply to every project on earth.

---

## Minimum Viable Steering File

If you're starting from zero, copy [templates/CLAUDE.md](../templates/CLAUDE.md) or the stack-specific variant, then fill in:

- [ ] Language version + framework version + banned alternates
- [ ] Test command and how to run a single test
- [ ] Error-handling shape (exceptions vs Result-type vs error returns)
- [ ] One example of the naming convention you expect
- [ ] At least one "do not" rule specific to your codebase
- [ ] A link to the content store (ARCHITECTURE.md, ADRs, glossary)

Six bullets is enough to start. You will add more as you catch the model doing things you didn't want.

---

## Nested `CLAUDE.md` — When to Split

One at the repo root for repo-wide rules. A second inside a subdirectory when that area has rules the rest of the repo doesn't share.

Examples that justify a nested file:

- `services/payments/CLAUDE.md` — PII handling, audit logging, idempotency requirements
- `packages/ui/CLAUDE.md` — component conventions, accessibility rules, Storybook coverage
- `infra/terraform/CLAUDE.md` — state locking, backend config, naming of IAM resources

Claude Code reads the closest `CLAUDE.md` first, then walks up. See [path-scoped-rules.md](path-scoped-rules.md) for directory-scoped loading order and override semantics.

---

## Keeping Steering Files Alive

A steering file that nobody updates rots. Rot manifests as: the model ignores rules that no longer match the codebase; reviewers stop quoting the file in PR comments; new team members ask questions the file was supposed to answer.

Two habits keep them alive:

- **Quote the file in every AI-PR review comment.** "This violates CLAUDE.md §3 — wrap the API call in our `tryCall` helper." The file earns its keep when it's the thing reviewers point at.
- **Prune monthly.** Delete rules that no longer apply. Update rules whose context has changed. See [anti-patterns.md §20](anti-patterns.md) on stale lessons.

---

## Related

- [harness-pattern.md](harness-pattern.md) — why steering is one of the three checks
- [path-scoped-rules.md](path-scoped-rules.md) — directory-scoped `CLAUDE.md` loading
- [templates/CLAUDE.md](../templates/CLAUDE.md) — starting point, 12 sections
- [prompt-discipline.md](prompt-discipline.md) — authority language (`MUST`, `WILL`, `NEVER`) and why `should/consider/try` weakens enforcement
