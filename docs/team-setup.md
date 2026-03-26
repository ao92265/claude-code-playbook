# Team Setup Guide

How to roll out the Claude Code Playbook to your team.

---

## Why Standardize?

Without shared conventions, every developer has a different Claude Code experience:
- Different prompting styles → inconsistent code quality
- No hooks → type errors caught at build time instead of edit time
- No CLAUDE.md → Claude learns your stack from scratch every session
- No skills → everyone reinvents the same workflows

Standardizing saves 10-20 minutes per developer per session. For a team of 5, that's 1-2 hours daily.

---

## Rollout Plan

### Phase 1: CLAUDE.md (Day 1)

**What:** Add a CLAUDE.md to every active project repository.

1. Choose the right [template](../templates/) for each project's stack
2. Customize sections to match your team's conventions
3. Commit to the repo — it's project documentation, not personal config
4. Review in a team PR so everyone aligns on conventions

**Impact:** Immediate. Every session starts with shared context instead of guessing.

### Phase 2: Hooks (Day 2-3)

**What:** Install hooks globally for all developers.

1. Share the hook scripts: copy to a shared location or include in your dotfiles repo
2. Share the [hooks-example.json](../config/hooks-example.json) configuration
3. Start with just `ts-check.sh` — it has the highest impact-to-effort ratio
4. Add more hooks incrementally as the team gets comfortable

**Impact:** Type errors caught at edit time. Formatting issues caught before commit.

### Phase 3: Essential Skills (Week 1)

**What:** Install the essential skill pack for all developers.

Recommended first skills:
- `/check-env` — eliminates "works on my machine" problems
- `/handoff` — enables clean session handoffs and async collaboration
- `/deploy` — standardizes the deployment checklist
- `/code-review` — consistent review format across the team

```bash
# Add to your team's setup script
for skill in check-env handoff deploy code-review; do
  cp -r playbook/skills/$skill ~/.claude/skills/
done
```

**Impact:** Shared workflows. Every developer follows the same deployment checklist.

### Phase 4: Advanced Skills (Week 2+)

**What:** Add skills based on team needs.

| Team Need | Skills to Add |
|:----------|:-------------|
| TDD culture | `/test-first`, `/refactor` |
| Security focus | `/security-check`, `/dependency-audit` |
| Complex features | `/writing-plans`, `/executing-plans`, `/brainstorming` |
| Release management | `/changelog`, `/pr-batch-review` |
| New team members | `/explain`, `/deep-explore` |

**Impact:** Domain-specific workflows that match how your team actually works.

---

## Configuration Strategy

### Global vs. Project-Local

| Type | Location | Use For |
|:-----|:---------|:--------|
| Global | `~/.claude/` | Skills and hooks that apply to all projects |
| Project | `.claude/` (in repo) | Skills and hooks specific to one project |
| Project | `CLAUDE.md` (in repo) | Rules and conventions for the project |

**Rule of thumb:** If it's about "how to use Claude Code" → global. If it's about "how to work on this project" → project-local.

### Settings Management

For teams, consider a shared settings template:

```bash
# In your team's dotfiles or setup repo
claude-team-config/
├── settings.json          # Shared settings template
├── hooks/                 # Shared hook scripts
├── skills/                # Team-standard skills
└── setup.sh               # Installation script
```

Each developer copies from the shared template and adds personal customizations.

> **Scaling beyond 20 developers?** See the [Enterprise Governance guide](enterprise-governance.md) for SSO, managed policies, Compliance API, and audit trail setup.

---

## Measuring Impact

Track these metrics before and after rollout:

| Metric | How to Measure |
|:-------|:--------------|
| Session success rate | % of sessions that complete the task without starting over |
| Time to fix bugs | From report to merged fix |
| Type errors in PRs | Count of TypeScript errors caught in CI (should drop to zero) |
| Build failures | Count of OOM or compilation failures (should drop) |
| Developer satisfaction | Survey: "How productive do you feel with Claude Code?" |

---

## Common Objections

**"I don't want to change my workflow"**
You're not changing your workflow — you're documenting it. CLAUDE.md just tells Claude the conventions you already follow.

**"Hooks slow me down"**
The ts-check hook takes 2-5 seconds. A type error caught at edit time vs. build time saves 10+ minutes.

**"Skills are too prescriptive"**
Skills are guides, not enforcements. `/deploy` reminds you to check env vars — it doesn't stop you from deploying without them.

**"My project is different"**
Every project is different. That's why we have 9 templates covering TypeScript, React, Node, Python, Go, Rust, Mobile, DevOps, and full-stack. Customize from the closest match.

---

## Maintenance

- **Monthly:** Review `tasks/lessons.md` across projects. Promote recurring lessons to CLAUDE.md.
- **Quarterly:** Review and update CLAUDE.md templates. Remove outdated conventions.
- **On new tool adoption:** Add hooks and skills for the new tool. Remove deprecated ones.
- **On new team member:** Walk through CLAUDE.md and installed skills. Have them read the [getting started guide](getting-started.md).
