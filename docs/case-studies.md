---
title: Case Studies
nav_order: 6
parent: Enterprise
---
# Case Studies

Real results from teams using the patterns in this playbook.

---

## Case Study 1: Enterprise TypeScript Platform

**Team:** 5 developers, B2B SaaS platform
**Stack:** TypeScript, React, Node.js, PostgreSQL
**Duration:** 6 months of Claude Code adoption

### Before

- Feature implementation: 2-3 weeks average
- Bug fix cycle: 3-5 days (triage → fix → review → deploy)
- Test suite: ~200 tests, inconsistent coverage
- TypeScript errors in PRs: frequent
- Deployments: manual, error-prone, 30+ minute process

### What They Did

1. **Week 1:** Added CLAUDE.md to all 4 repositories using the playbook templates
2. **Week 2:** Installed `ts-check.sh` and `env-guard.sh` hooks globally
3. **Week 3:** Rolled out `/check-env`, `/deploy`, and `/handoff` skills
4. **Month 2:** Adopted `/test-first` for all new features
5. **Month 3:** Started using multi-agent orchestration for large features

### After

| Metric | Before | After | Change |
|:-------|:------:|:-----:|:------:|
| Feature implementation | 2-3 weeks | 4-7 hours | **85% faster** |
| Bug fix cycle | 3-5 days | 30-45 minutes | **99% faster** |
| Test suite | ~200 tests | 10,000+ tests | **50x more** |
| TypeScript errors in PRs | Frequent | Zero | **Eliminated** |
| Deployment time | 30+ minutes | 5 minutes | **84% faster** |
| Regressions from AI code | Unknown | Zero | **Eliminated** |

### Key Insight

> "The biggest win wasn't speed — it was consistency. Every developer follows the same patterns because CLAUDE.md and skills enforce them. Code reviews went from 'please fix the style' to 'let's discuss the architecture.'"

---

## Case Study 2: Startup Mobile App

**Team:** 2 developers (1 full-time, 1 contractor)
**Stack:** React Native, TypeScript, Firebase
**Duration:** 3 months

### Before

- Shipping 1-2 features per sprint
- Contractor onboarding took 2 weeks before productive
- No consistent patterns between developers
- Firebase security rules were guessed at

### What They Did

1. Created CLAUDE.md using the Mobile template
2. Installed `/check-env` and `/security-check`
3. Used `/explain` for codebase documentation
4. Used `/handoff` at the end of every session for async collaboration

### After

| Metric | Before | After | Change |
|:-------|:------:|:-----:|:------:|
| Features per sprint | 1-2 | 5-8 | **3-4x more** |
| Contractor onboarding | 2 weeks | 2 days | **85% faster** |
| Security issues found | Post-launch | Pre-commit | **Shifted left** |

### Key Insight

> "The `/handoff` skill changed how we work asynchronously. I code in the morning, write a handoff, and my contractor picks up exactly where I left off in their evening. We effectively doubled our productive hours."

---

## Case Study 3: DevOps Team Migration

**Team:** 3 DevOps engineers
**Stack:** Terraform, Docker, GitHub Actions, AWS
**Duration:** 2 months

### Before

- Infrastructure changes took days of manual testing
- Terraform plans were reviewed by copying output into Slack
- Secrets accidentally committed 2-3 times per quarter
- No standardized deployment process

### What They Did

1. Created CLAUDE.md using the DevOps template
2. Installed `env-guard.sh` hook (secrets detection)
3. Used `/deploy` skill for all production changes
4. Used `/security-check` before every infrastructure PR

### After

| Metric | Before | After | Change |
|:-------|:------:|:-----:|:------:|
| Infrastructure change time | 2-3 days | 2-4 hours | **90% faster** |
| Secret exposure incidents | 2-3 per quarter | Zero | **Eliminated** |
| Failed deployments | ~20% | ~2% | **90% fewer** |

### Key Insight

> "The `env-guard.sh` hook paid for the entire playbook setup in the first week. We haven't accidentally committed a secret since."

---

## Common Patterns Across All Case Studies

1. **CLAUDE.md is the highest-leverage single file.** Every team cited it as the #1 improvement.
2. **Hooks catch mistakes humans miss.** Especially `ts-check.sh` and `env-guard.sh`.
3. **Skills create consistency.** Different developers produce similar-quality output when following the same skill workflow.
4. **`/handoff` enables async collaboration.** Teams working across time zones or with contractors benefit the most.
5. **Start small, add incrementally.** Every successful adoption started with CLAUDE.md + 2-3 skills, not the full playbook.

---

## Lessons from Production

Beyond the headline numbers, production experience uncovered patterns worth encoding in any project.

### Critical patterns

| Pattern | Lesson |
|---------|--------|
| Foreign Key Cascades | SQL Server rejects multiple cascade paths on the same table. Use `onDelete: NoAction` on secondary relations and handle cascades in application code |
| Adapter Imports | Import from `@prisma/adapter-mssql`, not the generic adapter package |
| Feedback Loops | Any automated function that both produces and scans the same resource must exclude its own output to prevent infinite loops |
| Emergency Disables | Track exactly what was disabled. Re-enable and verify all functions after the fix deploys |

### The replace-don't-append pattern

Never append to shared context files. Always replace the entire content, and keep it under 30 lines. Shared context files are read by every Claude session via CLAUDE.md; if sessions keep appending, the file grows unbounded, and once it exceeds the context window Claude silently drops it — losing all shared state. Every update should overwrite with only the current state.

### Multi-agent safety rules

| Rule | Rationale |
|------|-----------|
| No git stash in sub-agents | Sub-agents that stash can corrupt the working tree for the parent agent. Use worktrees for isolation instead |
| No branch switching | A sub-agent switching branches will confuse every other running agent. Each agent should work on its current branch only |
| Scope commits tightly | Each sub-agent should only commit the files it modified. Never use `git add -A` in a multi-agent context |
| Exit cleanly on failure | If a sub-agent fails, it must report the failure clearly rather than attempting recovery that might conflict with the parent |

### Context preservation

Important decisions and discoveries must survive across Claude sessions:

- **tasks.json** — structured task tracking with status, priority, and context fields
- **PROJECT_NOTES.md** — freeform decision log with dated entries, updated immediately after architectural or technical decisions
- **STRUCTURE.json** — machine-readable map of the codebase: modules, paths, purposes, dependencies

Even without a framework, the "dated decision log" pattern is worth adopting on its own.

### Local plugin marketplaces

Rather than stuffing everything into CLAUDE.md, encapsulate domain-specific knowledge into reusable plugins that can be versioned and shared:

```json
// In .claude/settings.json
{
  "extraKnownMarketplaces": {
    "your-project-plugins": {
      "source": {
        "source": "directory",
        "path": "./plugins"
      }
    }
  }
}
```

This treats a local `plugins/` directory as a plugin marketplace. Plugins load without depending on external registries and can be versioned alongside your project code.

---

*Want to share your team's results? [Open a discussion](https://github.com/ao92265/claude-code-playbook/discussions) or [submit a pattern](https://github.com/ao92265/claude-code-playbook/issues/new?template=pattern-submission.md).*
