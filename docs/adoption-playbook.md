---
title: Adoption Playbook
nav_order: 3
parent: Enterprise
---
# Adoption Playbook: Convincing Your Team (and Management)

A practical guide for getting buy-in and rolling out Claude Code across your organization.

---

## The 30-Second Pitch

> "Claude Code with standardized skills and hooks cuts feature development time by 80% and eliminates entire categories of bugs (type errors, secret leaks, formatting issues) automatically. It costs less than one hour of developer time per month and pays for itself in the first session."

---

## Building the Business Case

### Quantifiable Benefits

| Benefit | Typical Impact | How to Measure |
|:--------|:--------------|:---------------|
| Feature velocity | 3-5x faster | Compare sprint velocity before/after |
| Bug fix time | 90-99% reduction | Track time from report to merged fix |
| Type errors in PRs | Eliminated | Count TS errors caught in CI (should drop to zero) |
| Secret exposure risk | Eliminated | Track `env-guard.sh` catches |
| Onboarding time | 50-85% faster | Time for new dev to ship first feature |
| Code review time | 30-50% reduction | Track PR review cycle time |

### Cost

| Item | Cost |
|:-----|:-----|
| Claude Code subscription | $20-100/developer/month (depending on plan) |
| Playbook setup | 1-2 hours one-time per project |
| Ongoing maintenance | ~30 minutes/month reviewing CLAUDE.md and lessons |

### ROI Calculation

For a team of 5 developers averaging $150K salary ($75/hour):

| Without Playbook | With Playbook | Savings |
|:----------------|:-------------|:--------|
| 2 weeks per feature | 1-2 days per feature | ~$15,000/feature |
| 3 days per bug fix | 30 minutes per bug fix | ~$1,500/bug |
| 2 hours/week on type errors | 0 hours | ~$750/week |

**Monthly savings estimate: $15,000-40,000 for a 5-person team.**

---

## Addressing Common Objections

### "AI-generated code is low quality"

Without guardrails, yes. That's the whole point of this playbook:
- CLAUDE.md enforces your coding standards
- Hooks catch type errors and style issues automatically
- `/test-first` ensures test coverage
- `/code-review` provides structured quality checks
- Verification skills prevent premature "done" claims

### "Developers will become dependent on AI"

Claude Code augments skills, it doesn't replace them. Developers still:
- Design the architecture
- Make technology decisions
- Review generated code
- Write acceptance criteria
- Debug complex issues

The analogy: spreadsheets didn't make accountants dependent — they made them faster at the same job.

### "It's a security risk"

Claude Code runs locally. Your code isn't sent to train models. Additionally:
- `env-guard.sh` prevents committing secrets
- `/security-check` scans for OWASP Top 10 vulnerabilities
- CLAUDE.md includes explicit rules against pushing without permission
- All code goes through the same review process as human-written code

### "We can't afford another tool"

Calculate the cost of one developer spending 2 weeks on a feature that could take 2 days. The subscription pays for itself with the first feature.

### "Our codebase is too complex / proprietary"

Claude Code reads your codebase and CLAUDE.md at session start. The more context you provide (conventions, patterns, gotchas), the better the output. Complex codebases benefit MORE from standardized instructions, not less.

---

## Rollout Strategy

### Phase 1: Pilot (1-2 weeks)

1. Pick 1-2 enthusiastic developers as champions
2. Set up CLAUDE.md on one project
3. Install essential skills (`check-env`, `handoff`, `deploy`)
4. Install `ts-check.sh` hook
5. Track: time savings, bugs caught, developer satisfaction

### Phase 2: Expand (2-4 weeks)

1. Share pilot results with the team
2. Add CLAUDE.md to all active projects
3. Install hooks globally for all developers
4. Run a 30-minute team session on the playbook
5. Start tracking metrics across the team

### Phase 3: Standardize (1-2 months)

1. Adopt the full skill set relevant to your stack
2. Add Claude Code patterns to your team's engineering handbook
3. Include CLAUDE.md review in PR checklists
4. Monthly review of `tasks/lessons.md` across projects
5. Contribute team-specific skills back to the playbook

### Phase 4: Optimize (ongoing)

1. Create custom skills for your team's specific workflows
2. Fine-tune CLAUDE.md based on lessons learned
3. Train new team members using the onboarding materials
4. Share results and case studies internally
5. For enterprise scale (50+ devs), set up SSO and governance — see [Enterprise Governance](enterprise-governance.md)

---

## Presentation Template

Use this structure for a 10-minute pitch to management:

1. **Problem (2 min):** "We spend X hours/week on tasks that could be automated"
2. **Solution (2 min):** "Claude Code with standardized skills and hooks"
3. **Evidence (3 min):** Show case study metrics, or your pilot results
4. **Cost (1 min):** Subscription cost vs. estimated savings
5. **Ask (2 min):** "Approve a 2-week pilot with 2 developers"

**Key message:** This isn't about replacing developers. It's about eliminating the tedious 80% (type checking, boilerplate, debugging obvious issues) so developers focus on the creative 20% (architecture, design, complex problem solving).

---

## Spec-Driven Dev (2026 update)

The community has crystallised a six-tool stack — Big 5 + GS — that replaces ad-hoc prompting with a verifiable spec → plan → tasks → code pipeline. `specify` CLI is installed globally on this machine; start there.

- Read: [Spec-Driven Stack 2026](spec-driven-stack.md)
- Pilot: run `specify init` on one Wraith ticket. Compare cycle time vs. baseline.
- Layer existing playbook hooks (TS check, env-guard, security-reviewer subagent) on top — the stacks are complementary, not exclusive.

---

## Resources

- [Getting Started Guide](getting-started.md) — 10-minute setup
- [Spec-Driven Stack 2026](spec-driven-stack.md) — Big 5 + GS overview
- [Team Setup Guide](team-setup.md) — Detailed rollout plan
- [Case Studies](case-studies.md) — Real results from real teams
- [FAQ](faq.md) — Common questions answered
- [Anti-Patterns](anti-patterns.md) — Mistakes to avoid
