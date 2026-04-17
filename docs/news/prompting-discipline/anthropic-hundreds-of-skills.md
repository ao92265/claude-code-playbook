---
title: Anthropic runs hundreds of skills — I published 235, 12 run weekly
parent: Prompting & Discipline
grand_parent: News & Research
nav_order: 5
permalink: /docs/news/anthropic-hundreds-of-skills/
---
# Anthropic Runs Hundreds of Skills. I Published 235. After 6 Months, Only a Dozen Actually Run Weekly.

**Source:** Reza Rezvani, [Anthropic Runs Hundreds of Skills. I Published 235. After 6 Months, Only a Dozen Actually Run Weekly.](https://alirezarezvani.medium.com/anthropic-runs-hundreds-of-skills-fa524c84025f) (Medium, 2026-04-17, 12 min read)

## Subtitle

> "A seven-person team's field report on the Anthropic Claude Code skills playbook — what compounds, what rots, and the four categories that repay the audit."

## Key takeaways

- **235 skills published. 12 running weekly.** That's the audit result after 6 months on a seven-person team.
- **Anthropic's 9-category framework is correct as taxonomy but wrong as build order** for teams under ~10 engineers.
- **Three foundational rules hold at any scale:** skills are folders not files; Gotchas sections are the highest-leverage content; progressive disclosure is not optional.
- **Four categories compound at small scale:** Library/API References, Code Templates/Scaffolding, Business Processes/Team Automation, Code Quality/Code Review.
- **Three categories are traps at small scale:** Product Verification, Runbooks, Infrastructure Operations.
- **Skill-audit rule of thumb: 30 days unused → audit. 60 days unused → delete.** A rotten skill is worse than no skill.

## The methodology

> "The first time, I nodded at everything. Nine categories. Skills are folders, not files. Gotchas sections are the highest-leverage content. Progressive disclosure via the filesystem. All of it matched what I have been telling my engineering team for six months. The second time, I opened a spreadsheet."

- **Column A:** every skill in Rezvani's public `claude-skills` repository (235 of them)
- **Column B:** each skill mapped to an Anthropic category
- **Column C:** last time each skill was actually invoked by a human or by Claude on his team

> "By the time I finished, the number I cared about was not 235. It was twelve."

## Where the Anthropic playbook is completely right

### 1. Skills are folders, not markdown files

> "My adversarial-reviewer skill has a 90-line SKILL.md, three persona reference files, and one Python script that runs the diff analysis. The SKILL.md stays focused. The references load when needed. The script does deterministic work. Without the folder model, this skill would either be a 900-line prompt nobody maintains or a set of disconnected snippets Claude would not find."

### 2. The Gotchas section is the most valuable content in any skill

> "Every skill I keep has a Gotchas section that grows over time. It does not list theoretical edge cases. It lists specific things that broke in production, with the fix. When a junior engineer on my team hits the same edge case next month, Claude already knows what to do. The Gotchas section is where scar tissue becomes institutional memory. **If you take one idea from this article, take that one.**"

### 3. Progressive disclosure is not optional at scale

> "A skill that splits knowledge into `references/api.md`, `references/patterns.md`, and `references/common-mistakes.md` lets Claude load exactly what it needs. This matters at 48 skills. It matters ten times more at 235."

## Where the playbook breaks for small teams

Three categories are **traps at 7-person scale** — correct descriptions of real work, wrong prescription for build order.

### Trap 1 — Product Verification skills

> "The playbook suggests it is worth dedicating an engineer for a week to polish a verification skill. On a seven-person team, one week of one engineer is roughly 2.8% of total quarterly capacity for one skill. That skill would need to run frequently enough to repay almost three percent of quarterly engineering time. Most verification targets at our scale do not hit that bar."

A signup-flow-driver skill sits idle most weeks. Maintenance cost arrives on schedule; return does not.

### Trap 2 — Runbook skills

> "Incidents at our scale happen two or three times per quarter. By the time we need the runbook, the underlying systems have usually changed enough that the runbook is half-wrong. A runbook skill is most valuable when it runs often enough to stay calibrated. Ours does not."

Keep runbooks in `docs/runbooks/`, re-read manually when something breaks, update after postmortem. Don't skillify them.

### Trap 3 — Infrastructure Operations skills

> "We have one VPS, one managed Postgres, and a handful of queues. There is not enough infrastructure to operate to amortize the cost of a skill that understands it. An engineer at a company running hundreds of services per cluster gets ten invocations a day of a resource-orphans skill. We might get ten per year. The drift between uses becomes a liability."

## The four categories that compound

### Category 1 — Library and API References

> "Highest-return category for any team using libraries Claude does not know well. Internal libraries. New public libraries. Libraries with counterintuitive edge cases. A skill in this category runs every time Claude touches a file that imports the library."

**Example — Apple HIG expert skill:**

```markdown
---
name: apple-hig-expert
description: Use when building iOS, iPadOS, macOS, or visionOS interfaces.
  Loads Apple Human Interface Guidelines expertise, including Liquid Glass
  aesthetic, platform-specific spacing, typography, and motion patterns.
  Trigger on any request involving SwiftUI, UIKit, or native Apple UI.
---
# Apple HIG Expert
## When to use this skill
- Building a new native screen or flow for any Apple platform
- Reviewing an existing UI for HIG compliance
- Making platform-specific adaptation decisions
## Core references
- references/liquid-glass.md - current visual language (iOS 26+)
- references/spacing-and-typography.md - SF Symbols, type ramp, hit targets
- references/motion-patterns.md - spring animations, interruption handling
- references/platform-adaptation.md - when to diverge iPhone/iPad/Mac
## Gotchas
- Do not default to Material Design spacing (8pt grid on Apple, not 4pt/8dp)
- SF Pro is the default; fall back to system font, never to Inter or Roboto
- Sheets have three detents on iOS 16+; do not hardcode heights
- `.hoverEffect` only applies on iPadOS and visionOS - gate it properly
- Symbol weights must match surrounding text weight, not accent color
```

> "Claude invokes this skill multiple times per week without anyone asking. Maintenance cost is low because Apple publishes HIG updates on a predictable cadence."

### Category 2 — Code Templates and Scaffolding

> "Where skills earn their keep fastest. Any code artifact your team creates more than once per week is a candidate. Routes. Migrations. Database schemas. Workflow handlers. The scaffolding skill turns five-minute boilerplate tasks into ten-second tasks."

**Example — Database schema designer skill:**

```markdown
---
name: database-schema-designer
description: Use when translating requirements into Postgres schema artifacts.
  Produces migrations, TypeScript types, seed data, and RLS policies in one
  coherent set. Trigger on requests containing "new table", "schema for",
  "add column", or any description of entity relationships.
---
# Database Schema Designer
## Standard output set
For any new schema change, produce all four artifacts:
1. Migration file in supabase/migrations/YYYYMMDDHHMMSS_description.sql
2. TypeScript types in src/types/database.ts (diff-safe append)
3. Seed data in supabase/seed.sql (idempotent INSERT ... ON CONFLICT)
4. RLS policies - deny-by-default, explicit grants per role
## Gotchas
- Never drop a column in the same migration that renames a table - do two migrations
- `created_at` and `updated_at` always default to `now()` with a trigger for updated_at
- Foreign keys always use `ON DELETE` explicitly - no implicit defaults
- RLS policies must cover SELECT, INSERT, UPDATE, and DELETE - check all four
- TypeScript types regeneration runs after migration, not before - never edit manually
```

> "Schema changes happen one to three times per week on our team. Enough invocation frequency to keep the skill calibrated."

### Category 3 — Business Processes and Team Automation

> "The single highest-return category for small teams, and the one most people underinvest in. Anthropic's playbook lists it fourth. **For small teams I would list it first.**"

The economic argument: business process skills run **multiple times per person per week** — not per quarter. Five people × five days × a few minutes each = meaningful compounding.

**Example — Standup post skill:**

```markdown
---
name: standup-post
description: Use when preparing a daily standup or async status update.
  Aggregates yesterday's closed tasks, merged PRs, and outstanding blockers
  from our tracker and GitHub, then produces a formatted standup post.
  Trigger on "standup", "status update", or "what did I ship yesterday".
---
# Standup Post Builder
## Inputs (from environment)
- Linear API token (env: LINEAR_API_KEY)
- GitHub token with repo read access (env: GITHUB_TOKEN)
- Slack channel ID (env: STANDUP_CHANNEL)
## Output format
Three sections, each two to five bullet points:
1. Shipped yesterday - closed tickets and merged PRs only
2. Working on today - in-progress tickets, current PR reviews
3. Blocked on - dependencies, waiting-for-review items, open questions
## Gotchas
- Do not include tickets that were closed without being shipped (status=Cancelled)
- Draft PRs do not count as "shipped" even if merged - check the PR status
- If a blocker repeats three days in a row, escalate it with "BLOCKED x3"
- Read standups.log before composing - do not repeat "working on today" items
  that appeared as "shipped yesterday" in the last run
```

**25 invocations per week on a 5-person team.** Near-zero maintenance cost. Better standups in 30 seconds vs 5 minutes.

### Category 4 — Code Quality and Code Review

> "Code review skills run on every pull request, which makes this the highest-frequency compounding category after scaffolding. The hard part is avoiding the rubber-stamp problem. Claude, left alone, tends to give warm, agreeable reviews. **You need a skill that forces it to be uncomfortable.**"

**Example — Adversarial reviewer skill:**

```markdown
---
name: adversarial-reviewer
description: Adversarial code review that breaks the self-review monoculture.
  Use when reviewing code before merging a PR, or when you suspect Claude is
  being too agreeable about code quality. Forces three hostile personas —
  each MUST find at least one issue.
---
# Adversarial Code Reviewer
## The three personas (non-negotiable)
### Saboteur
Priority: what breaks in production at 3am.
- Race conditions, retries without idempotency, silent failures
- Timezone bugs, DST edge cases, leap years
- Out-of-memory conditions, unbounded collections
- Each finding must include the scenario that triggers it
### New Hire
Priority: can someone with no context maintain this in six months.
- Variable names, function length, nested conditionals
- Missing tests for branches the author "knows" are safe
- Comments that explain "what" instead of "why"
### Security Auditor
Priority: OWASP top ten, then environment secrets.
- Input validation at every boundary
- SQL injection, XSS, SSRF, path traversal
- Hardcoded credentials, leaked tokens, CORS misconfigurations
## Rules of engagement
- Each persona MUST surface at least one finding - no "LGTM" allowed
- Findings classified as BLOCK, CONCERN, or NOTE
- Duplicate findings from two personas are promoted one severity level
- Final verdict: BLOCK / CONCERNS / CLEAN
```

> "Runs on every non-trivial PR — typically three to five invocations per week. The return is that rubber-stamp Claude does not ship to production."

## The 30/60 rule for skill maintenance

> "A skill that does not run at least monthly will rot. The world changes around it. The library it wraps ships a breaking update. The process it automates gets replaced. The team member who wrote it leaves. Six months later, Claude invokes it on an unfamiliar task and produces confidently wrong output. **That is worse than having no skill at all.**"

### The rule

- **30 days without invocation:** audit the skill
- **60 days without invocation:** delete the skill

> "Twelve active skills beat 235 published ones every single week."

## The marketplace problem at small scale

> "Anthropic recommends an internal plugin marketplace for distribution. At hundreds-of-skills scale with thousands of engineers, that architecture makes sense. At our scale, it does not. What works better for a team of seven: a single README with a category index, a one-command installation snippet, and an explicit 'deprecated' section that is usually larger than people expect. **Naming collisions between similar skills are the biggest failure mode at small scale. The cure is tight naming discipline and fewer skills, not a marketplace.**"

## Honest limitations

> "I have not tested this past 235 skills or beyond a seven-person team. If you run an SRE team handling twenty incidents a week, runbook skills will compound for you in ways they do not for me. If you ship ten services a day, verification skills hit the invocation threshold ours never reach. The categories I called traps are traps at our scale. At yours, they might be the most important category."

> "My workload skews to product engineering plus content production. That weights categories one, two, and three. A backend-only team would spend more time in scaffolding. A data team would spend most of its budget in retrieval and analysis, which I barely covered."

> "Anthropic's framework is correct at Anthropic's scale. I am pushing back on the build order, not the taxonomy. A founder reading this should not delete categories from their skills roadmap based on my report. They should run the audit on their own invocation data and let the numbers decide."

## Frequently Asked Questions (from the article)

### Should small teams use Anthropic's nine-category framework as-is?

> "Use it as a taxonomy, not as a build order. The categories are correct descriptions of real work. The implicit recommendation to populate all nine is wrong for teams under ten engineers. **Start with Library References, Scaffolding, Business Process automation, and Code Review.** Revisit the other five after six months, when you have real invocation data."

### How do I know if a Claude Code skill is worth keeping?

> "One rule. If it has not been invoked in the last thirty days, audit it. If sixty days, delete it. Skills that do not run rot. A rotten skill is worse than no skill, because Claude will still invoke it and produce confidently wrong output."

### What is the minimum viable Claude Code skill library for a five-person team?

> "Three skills, each in a different category. A scaffolding skill for whatever code artifact you create most often. A code review skill that forces adversarial critique. One team automation skill — standup, weekly recap, or ticket creation. Ship those three. Use them for a month. The fourth skill you need will make itself obvious."

## What to do next

Rezvani's recommendation:

1. **Clone `github.com/alirezarezvani/claude-skills`** — 235 skills, MIT-licensed, cross-compatible across Claude Code, OpenAI Codex, OpenClaw, Hermes, Gemini CLI, Cursor, and 8 more agents. **11.2K stars** and growing.
2. **Delete two-thirds of it.**
3. **Keep the dozen that map to work you actually do.**
4. **Add Gotchas sections as your team hits edge cases.**
5. **Six months later your working set should look nothing like his** — and that is the correct outcome.

> "The point of skills is not to have the most of them. It is to have the ones that run often enough to compound while you sleep."

## Why this matters for Harris / Constellation

Directly applicable to the 4 TypeScript projects (Wraith, ACT, Centurion, NanoClaw):

1. **Audit your OMC skill library with Rezvani's methodology.** Pull invocation data (the Rezvani monitoring stack gives you this). Count what actually ran last 30 days. Everything else: audit or delete.
2. **The 4 compounding categories map directly:** Library references (for Zoho API, Azure APIs, specific internal libraries), Scaffolding (Wraith/Centurion/NanoClaw have repeated code artefacts), Business processes (standups, ticket creation, weekly summaries for small-team Harris product squads), Adversarial code review (essential for any PR touching regulated code).
3. **The 3 traps apply at our scale too.** FIS product teams are small; dedicating a week to a verification skill probably won't compound. Runbooks are better as markdown.
4. **Skill bloat has a real cost:** "A rotten skill is worse than no skill, because Claude will still invoke it and produce confidently wrong output." Validates the CLAUDE.md lesson about skill bloat with concrete audit data.

## About the author

Reza Rezvani — Berlin-based CTO. Creator of the open-source **claude-skills library (235+ skills, 11.2K stars)**. Daily Claude Code user since research preview. Also maintains openLEO, a self-hosted multi-agent orchestration platform in production since January 2026.

- Website: alirezarezvani.com
- GitHub: github.com/alirezarezvani
- Newsletter: claude-code.beehiiv.com

## Related Playbook pages

- [9 Agent Skills Repos I Tried]({{ site.baseurl }}/docs/news/nine-skills-repos/) — Njenga's complementary curated review
- [Skills Ecosystem]({{ site.baseurl }}/docs/skills-ecosystem/) — the public registry
- [/skillify — the internal skill]({{ site.baseurl }}/docs/news/skillify-hidden-skill/) — auto-generate skills from patterns
- [The New Claude Code Monitoring]({{ site.baseurl }}/docs/news/claude-code-monitoring/) — invocation data is how you run this audit
- [Prompt Discipline]({{ site.baseurl }}/docs/prompt-discipline/) — the authority/commitment patterns apply at skill level too
