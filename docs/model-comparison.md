# Claude Model Comparison Guide

Practical guidance on choosing the right Claude model for each task in Claude Code.

---

## Model Family Overview

Claude Code uses the Claude 4.5/4.6 model family. The three tiers trade off speed, cost, and reasoning depth:

| Model | Speed | Cost | Context Window | Best For |
|-------|-------|------|---------------|----------|
| **Haiku 4.5** | Fastest | Lowest | 200K tokens | Simple lookups, formatting, boilerplate |
| **Sonnet 4.6** | Fast | Medium | 200K tokens | Standard implementation, editing, testing |
| **Opus 4.6** | Slower | Highest | 1M tokens | Complex reasoning, architecture, debugging |

---

## When to Use Each Model

### Haiku 4.5 — The Quick Worker

Use Haiku for tasks that need speed over depth:

- **File searches and exploration** — "Find all files that import UserService"
- **Formatting and boilerplate** — "Generate TypeScript interfaces from this JSON"
- **Simple lookups** — "What's the return type of this function?"
- **Code generation from templates** — "Create a new React component following the existing pattern"
- **Documentation writing** — READMEs, comments, migration notes

**Don't use Haiku for:** Complex debugging, architecture decisions, multi-step reasoning, or code that needs careful security review.

### Sonnet 4.6 — The Daily Driver

Sonnet handles 80% of daily coding work:

- **Feature implementation** — Building new features across multiple files
- **Bug fixes** — Diagnosing and fixing bugs with test verification
- **Code editing** — Refactoring, renaming, extracting functions
- **Test writing** — Unit tests, integration tests, test data generation
- **Code review** — Finding issues and suggesting improvements
- **Build and type errors** — Fixing compilation failures

**Don't use Sonnet for:** Architecture-level decisions affecting the entire codebase, extremely subtle bugs requiring deep reasoning, or critical security audits.

### Opus 4.6 — The Deep Thinker

Reserve Opus for tasks where getting it wrong is expensive:

- **Architecture decisions** — System design, API design, data modeling
- **Complex debugging** — Multi-layer bugs, race conditions, subtle logic errors
- **Security audits** — Vulnerability analysis requiring deep understanding
- **Code review (critical)** — API contracts, backward compatibility, edge cases
- **Multi-step reasoning** — Tasks requiring 5+ steps of connected logic
- **Team lead coordination** — Orchestrating multiple agents, plan verification

**Don't use Opus for:** Simple edits, file searches, boilerplate generation, or any task Sonnet can handle equally well.

---

## Sub-Agent Model Routing

When spawning sub-agents with the Agent/Task tool, set the `model` parameter:

```
# Simple file search
Agent(model: "haiku", prompt: "Find all API route handlers in src/")

# Standard implementation
Agent(model: "sonnet", prompt: "Implement the pagination for the users endpoint")

# Architecture review
Agent(model: "opus", prompt: "Review the authentication architecture for security issues")
```

### Routing Rules of Thumb

| Task Type | Model | Why |
|-----------|-------|-----|
| File discovery, grep, glob | haiku | Speed matters, reasoning doesn't |
| Standard code changes | sonnet | Good balance of quality and cost |
| Writing tests | sonnet | Pattern-following, not deep reasoning |
| Fixing type errors | sonnet | Mechanical corrections |
| Writing docs | haiku | Template-based, fast iteration |
| Debugging (simple) | sonnet | Most bugs are straightforward |
| Debugging (complex) | opus | Subtle bugs need deep reasoning |
| Architecture review | opus | Decisions are expensive to reverse |
| Security review | opus | Missing a vulnerability is costly |
| Plan verification | opus | Catching plan flaws saves hours |

---

## Cost Optimization

### The 80/20 Rule

- **80% of tasks** should use Sonnet — it's your default
- **15% of tasks** can use Haiku — simple, fast, cheap
- **5% of tasks** need Opus — complex, critical, expensive

### Practical Tips

1. **Start with Sonnet, escalate to Opus when stuck.** If Sonnet can't solve it in 2 attempts, switch to Opus.
2. **Use Haiku for parallel fan-out.** When spawning 3-4 agents for exploration, use Haiku to keep costs down.
3. **Don't use Opus for verification.** Sonnet can verify work — Opus is for generating complex solutions.
4. **Batch simple tasks.** Instead of 4 separate Haiku calls, combine into one Sonnet call if the tasks are related.
5. **Monitor with `/context`.** If you're burning through context quickly, you might be over-reasoning on simple tasks.

### Cost Comparison (Approximate)

For a typical 10-file feature implementation session:

| Strategy | Relative Cost |
|----------|--------------|
| All Opus | 5x |
| All Sonnet | 1x (baseline) |
| Smart routing (Haiku + Sonnet + Opus) | 0.7x |
| All Haiku (if it could handle it) | 0.2x |

Smart routing — using the right model for each task — typically saves 30-50% versus defaulting to the most capable model.

---

## Model Selection Flowchart

```
Is it a simple lookup or search?
  → Yes: Haiku
  → No: ↓

Is it standard implementation, editing, or testing?
  → Yes: Sonnet
  → No: ↓

Does it involve architecture, security, or complex debugging?
  → Yes: Opus
  → No: Sonnet (default)
```

When in doubt, use Sonnet. It handles most tasks well and you can always escalate.
