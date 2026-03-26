# Claude Code Cost Guide

Real token usage and cost data to help you budget, optimize, and justify the investment.

---

## How Claude Code Billing Works

Claude Code charges based on **tokens** — the units of text that Claude reads and generates. Every session consumes tokens for:

1. **System context** — CLAUDE.md, skill definitions, hook outputs (~2,000-5,000 tokens)
2. **Code reading** — Files Claude reads to understand your codebase
3. **Conversation** — Your prompts and Claude's responses
4. **Tool use** — Each file edit, bash command, or search
5. **MCP servers** — Tool definitions from enabled servers (~200-5,000 tokens each)

---

## Typical Session Costs

Based on real production usage with the Claude API pricing (as of 2026):

| Session Type | Duration | Tokens Used | Haiku Cost | Sonnet Cost | Opus Cost |
|:-------------|:--------:|:-----------:|:----------:|:-----------:|:---------:|
| Quick bug fix | 5-10 min | 10K-30K | $0.03-0.10 | $0.10-0.30 | $0.50-1.50 |
| Standard feature | 15-30 min | 30K-80K | $0.10-0.25 | $0.30-0.80 | $1.50-4.00 |
| Complex feature | 30-60 min | 80K-200K | $0.25-0.65 | $0.80-2.00 | $4.00-10.00 |
| Multi-agent feature | 30-60 min | 150K-400K | $0.50-1.30 | $1.50-4.00 | $8.00-20.00 |
| Code review | 10-20 min | 20K-60K | $0.07-0.20 | $0.20-0.60 | $1.00-3.00 |
| Debugging session | 15-45 min | 40K-120K | $0.13-0.40 | $0.40-1.20 | $2.00-6.00 |
| Planning session | 10-20 min | 15K-50K | $0.05-0.15 | $0.15-0.50 | $0.75-2.50 |

*Costs are approximate. Actual costs depend on codebase size, conversation length, and model choice.*

---

## Monthly Cost Estimates by Role

| Developer Profile | Sessions/Day | Model Mix | Est. Monthly Cost |
|:-----------------|:------------:|:----------|:-----------------:|
| Light user (bug fixes, reviews) | 3-5 | 90% Sonnet, 10% Opus | $15-40 |
| Standard user (features + fixes) | 5-10 | 80% Sonnet, 20% Opus | $40-100 |
| Power user (multi-agent, complex) | 10-20 | 70% Sonnet, 30% Opus | $100-250 |
| Team lead (reviews, architecture) | 3-8 | 50% Sonnet, 50% Opus | $50-150 |

### Team Cost Example

5-person team, standard usage:

| | Monthly | Annual |
|:--|:------:|:------:|
| Claude Code usage | $200-500 | $2,400-6,000 |
| Subscription fees | $100-500 | $1,200-6,000 |
| **Total** | **$300-1,000** | **$3,600-12,000** |

> **Note:** Claude Code Team plan is $150/user/month ($1,500/month for 10 developers, $18,000/year). This is the highest-cost AI coding tool on the market. See the [comparison guide](comparison.md) for a hybrid strategy that can reduce costs 40-50%.

---

## ROI Calculator

### Time Saved Per Developer

| Task | Without Claude Code | With Claude Code | Time Saved |
|:-----|:------------------:|:----------------:|:----------:|
| Feature (medium) | 3-5 days | 4-8 hours | ~80% |
| Bug fix | 2-4 hours | 15-30 min | ~85% |
| Code review | 30-60 min | 10-15 min | ~70% |
| Writing tests | 2-3 hours | 30-45 min | ~75% |
| Debugging | 1-4 hours | 15-45 min | ~80% |
| Documentation | 1-2 hours | 15-30 min | ~80% |

### Dollar Value

For a developer earning $150K/year ($75/hour):

| Task | Hours Saved/Week | Weekly Value | Annual Value |
|:-----|:----------------:|:------------:|:------------:|
| Features | 8-16 hours | $600-1,200 | $31K-62K |
| Bug fixes | 2-4 hours | $150-300 | $8K-16K |
| Reviews + tests | 2-4 hours | $150-300 | $8K-16K |
| **Total per developer** | **12-24 hours** | **$900-1,800** | **$47K-94K** |

**ROI: 40-80x return on Claude Code investment.**

---

## Enterprise ROI: The Honest Numbers

The ROI numbers above reflect individual developer productivity gains. Enterprise-wide measurement tells a more nuanced story.

### The Perception-Reality Gap

Industry research across ~40,000 developers found:
- Developers **feel** 24% faster but **measure** 19% slower on complex tasks
- 15-25% of "time saved" coding is spent debugging AI-generated code
- Actual measured organisational ROI: **5-15% improvement** in delivery metrics
- High-performing implementations (strong governance + training) exceed **500% ROI**

The gap exists because AI excels at boilerplate and scaffolding but can introduce subtle bugs in complex logic. Teams that train developers to review AI output effectively close this gap.

### Enterprise Benchmarks

| Org Size | Investment | 3-Year ROI | Payback Period |
|:---------|:----------|:-----------|:--------------|
| Small (50-200 devs) | $100K-500K | 150-250% | 12-18 months |
| Mid-market (200-1K devs) | $500K-2M | 200-400% | 8-15 months |
| Large (1K+ devs) | $2M-10M+ | 300-600% | 6-12 months |

### Total Cost of Ownership (10-Developer Team)

Don't just count subscription fees. The real cost includes:

| Cost Category | Annual Cost |
|:-------------|:-----------|
| Claude Code Team subscriptions (10 × $150/mo) | $18,000 |
| API usage (overages beyond included quota) | $2,000-6,000 |
| Training and onboarding (initial) | $2,000-4,000 |
| Debugging overhead (15-25% of saved time) | Included in productivity |
| **Total** | **$22,000-28,000** |

Against savings of $200K-400K/year in developer productivity, the ROI remains strong — but the honest number is **8-15x**, not the 40-80x that ignores hidden costs.

### Metrics That Actually Matter

**Leading indicators** (measure monthly):
- Code review turnaround time (target: 20-30% reduction)
- Deployment frequency
- AI-assisted code acceptance rate per developer

**Lagging indicators** (measure quarterly):
- Change failure rate
- Defect escape rate (bugs reaching production)
- Technical debt trend (are you accumulating or reducing?)

Track these before and after rollout. Without a baseline, you can't prove ROI.

---

## Cost Optimization Strategies

### 1. Smart Model Routing (Saves 30-50%)

The single biggest cost lever. Most tasks don't need Opus.

| Task | Use | Why |
|:-----|:----|:----|
| File searches, formatting | Haiku | Speed matters, reasoning doesn't |
| Standard implementation | Sonnet | Best cost/quality balance |
| Bug fixes, tests | Sonnet | Pattern-following, not deep reasoning |
| Architecture decisions | Opus | Expensive to reverse, worth the cost |
| Complex debugging | Opus | Subtle bugs need deep reasoning |

For sub-agents, always set the model explicitly:
```
Agent(model: "haiku", ...)   # searches, simple tasks
Agent(model: "sonnet", ...)  # implementation
Agent(model: "opus", ...)    # architecture only
```

### 2. Context Management (Saves 10-20%)

Polluted context = wasted tokens on irrelevant information.

- `/clear` when switching tasks (don't carry old context into new work)
- `/compact` at 50% (compresses context, reducing token usage)
- Fresh session above 80% (polluted sessions burn tokens on confusion)
- One task per session (multi-task sessions use 2-3x more tokens)

### 3. Scope Locking (Saves 10-15%)

Every file Claude reads costs tokens. Scope locking limits what it reads:

```
Only modify files in src/auth/
```

Without this, Claude might explore the entire codebase looking for related code.

### 4. Disable Unused MCP Servers (Saves 5-10%)

Each MCP server adds tool definitions to every session start. Check with `/mcp`:

| MCP Servers Enabled | Token Overhead |
|:------------------:|:--------------:|
| 1-2 servers | ~500 tokens |
| 3-5 servers | ~2,000 tokens |
| 5-10 servers | ~5,000+ tokens |

Disable servers you haven't used in the last 3 sessions.

### 5. Efficient Prompting (Saves 5-10%)

| Instead of | Use |
|:-----------|:----|
| "The login is broken, can you look into it?" | "Login fails with 401 at src/auth/login.ts:42" |
| Describing the error in your words | Pasting the actual stack trace |
| "Make the code better" | "Extract the validation into a separate function" |
| Iterating 5 times on vague specs | Using reverse prompting once |

---

## Cost by Hook

Hooks add small costs per invocation:

| Hook | Tokens per Run | Cost per Run (Sonnet) |
|:-----|:--------------:|:---------------------:|
| ts-check.sh | ~100 (output only) | <$0.001 |
| lint-check.sh | ~100 (output only) | <$0.001 |
| format-check.sh | ~50 (output only) | <$0.001 |
| build-check.sh | ~200 (output only) | <$0.001 |

Hooks are essentially free. Their cost is negligible compared to the time they save by catching errors early.

---

## Budgeting for Your Team

### Quick Formula

```
Monthly cost ≈ (developers × sessions/day × 20 workdays × avg cost/session)
```

**Example:** 5 developers × 8 sessions/day × 20 days × $0.50/session = **$400/month**

### Budget Justification Template

```
Current state:
- 5 developers × $150K avg salary = $750K/year in developer costs
- Average feature takes 3-5 days
- Average bug fix takes 2-4 hours

With Claude Code Playbook:
- Average feature takes 4-8 hours (80% faster)
- Average bug fix takes 15-30 minutes (85% faster)
- Zero type errors, zero secret leaks, consistent code quality

Investment: ~$6,000-12,000/year
Savings: ~$200,000-400,000/year in developer productivity
ROI: 30-60x
```

---

## Tracking Your Costs

1. **Per-session:** Run `/context` at the end of each session to see token usage
2. **Monthly:** Check your Anthropic dashboard for usage breakdown
3. **Per-project:** Track sessions per project to identify high-cost areas
4. **Optimize:** Review model routing monthly — are you using Opus where Sonnet would suffice?
